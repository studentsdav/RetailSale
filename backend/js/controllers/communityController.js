const db = require('../config/db');

/**
 * Get or query regional channels and direct merchant conversations
 */
exports.getConversations = async (req, res) => {
  try {
    const { city = 'Dehradun', merchant_id } = req.query;

    const query = `
      SELECT c.*, 
        (
          SELECT json_build_object(
            'id', m.id, 
            'content', m.content, 
            'sender_name', m.sender_name, 
            'created_at', m.created_at, 
            'is_deleted_for_everyone', m.is_deleted_for_everyone
          ) 
          FROM community_messages m 
          WHERE m.conversation_id = c.id 
          ORDER BY m.created_at DESC 
          LIMIT 1
        ) as last_message
      FROM community_conversations c
      WHERE (c.is_direct = FALSE AND LOWER(c.region_city) = LOWER($1))
         OR (c.is_direct = TRUE AND (c.id LIKE '%' || $2 || '%' OR c.direct_recipient_id = $2))
      ORDER BY c.updated_at DESC
    `;

    const { rows } = await db.query(query, [city, merchant_id || '']);
    return res.json({ success: true, data: rows });
  } catch (error) {
    console.error('Error fetching conversations:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * Get messages for a conversation (excluding messages hidden via 'Delete for Me')
 */
exports.getMessages = async (req, res) => {
  try {
    const { conversation_id, merchant_id } = req.query;

    if (!conversation_id) {
      return res.status(400).json({ success: false, error: 'conversation_id is required' });
    }

    const query = `
      SELECT m.*, 
        COALESCE(json_agg(DISTINCT d.user_id) FILTER (WHERE d.user_id IS NOT NULL), '[]') as deleted_for_user_ids,
        COALESCE(json_agg(DISTINCT men.mentioned_handle) FILTER (WHERE men.mentioned_handle IS NOT NULL), '[]') as mentioned_handles
      FROM community_messages m
      LEFT JOIN community_message_deleted_users d ON m.id = d.message_id
      LEFT JOIN community_message_mentions men ON m.id = men.message_id
      WHERE m.conversation_id = $1
        AND (d.user_id IS NULL OR d.user_id != $2)
      GROUP BY m.id
      ORDER BY m.created_at ASC
    `;

    const { rows } = await db.query(query, [conversation_id, merchant_id || '']);
    return res.json({ success: true, data: rows });
  } catch (error) {
    console.error('Error fetching messages:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * Send a new message with @mention extraction and live broadcast
 */
exports.sendMessage = async (req, res) => {
  try {
    const {
      id,
      conversation_id,
      sender_id,
      sender_name,
      sender_trade_name = '',
      sender_city = '',
      sender_gstin = '',
      sender_phone = '',
      content,
      attachment = null,
    } = req.body;

    if (!content && !attachment) {
      return res.status(400).json({ success: false, error: 'Message content or attachment is required' });
    }

    const msgId = id || `msg_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

    // 0. Ensure conversation exists in community_conversations (Foreign Key safety)
    const isDirect = conversation_id.startsWith('direct_');
    const cleanCity = (sender_city || 'Dehradun').trim();
    const autoTitle = isDirect
      ? 'Direct Merchant Chat'
      : `# ${conversation_id.replace(/^channel_/, '').replace(/_/g, ' ')}`;

    await db.query(
      `
      INSERT INTO community_conversations 
      (id, title, description, region_city, region_state, is_direct, created_at, updated_at)
      VALUES ($1, $2, '', $3, '', $4, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT (id) DO UPDATE SET updated_at = CURRENT_TIMESTAMP
    `,
      [conversation_id, autoTitle, cleanCity, isDirect]
    );

    // 1. Insert message
    const insertQuery = `
      INSERT INTO community_messages 
      (id, conversation_id, sender_id, sender_name, sender_trade_name, sender_city, sender_gstin, sender_phone, content, attachment, created_at)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, CURRENT_TIMESTAMP)
      RETURNING *
    `;
    const { rows } = await db.query(insertQuery, [
      msgId,
      conversation_id,
      sender_id,
      sender_name,
      sender_trade_name,
      sender_city,
      sender_gstin,
      sender_phone,
      content || '',
      attachment ? JSON.stringify(attachment) : null,
    ]);

    // 2. Parse and index @mentions
    const mentionRegex = /@([a-zA-Z0-9_-]+)/g;
    let match;
    const mentionedHandles = [];
    if (content) {
      while ((match = mentionRegex.exec(content)) !== null) {
        const handle = match[1];
        mentionedHandles.push(handle);
        await db.query(
          `INSERT INTO community_message_mentions (message_id, mentioned_handle) VALUES ($1, $2)`,
          [msgId, handle]
        );
      }
    }

    // 3. Update Conversation updated_at
    await db.query(
      `UPDATE community_conversations SET updated_at = CURRENT_TIMESTAMP WHERE id = $1`,
      [conversation_id]
    );

    const messagePayload = {
      ...rows[0],
      mentioned_handles: mentionedHandles,
      deleted_for_user_ids: [],
    };

    // Broadcast through socket.io if attached to req.app
    const io = req.app.get('io');
    if (io) {
      io.to(conversation_id).emit('new_message', messagePayload);
    }

    return res.status(201).json({ success: true, data: messagePayload });
  } catch (error) {
    console.error('Error sending message:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * Delete for Everyone (STRICT 2-HOUR AUDIT-SAFE REVOKE WINDOW)
 */
exports.deleteForEveryone = async (req, res) => {
  try {
    const { message_id, sender_id } = req.body;

    if (!message_id || !sender_id) {
      return res.status(400).json({ success: false, error: 'message_id and sender_id are required' });
    }

    // 1. Fetch message
    const { rows } = await db.query(`SELECT * FROM community_messages WHERE id = $1`, [message_id]);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Message not found' });
    }

    const message = rows[0];

    // 2. Ownership check
    if (message.sender_id !== sender_id) {
      return res.status(403).json({
        success: false,
        error: 'You can only delete your own messages for everyone',
      });
    }

    // 3. Strict 2-Hour Time-lock check
    const now = new Date();
    const createdAt = new Date(message.created_at);
    const diffHours = (now.getTime() - createdAt.getTime()) / (1000 * 60 * 60);

    if (diffHours >= 2) {
      return res.status(400).json({
        success: false,
        error: 'Delete for everyone has expired. Messages older than 2 hours cannot be revoked.',
      });
    }

    // 4. Overwrite message payload safely
    await db.query(
      `
      UPDATE community_messages 
      SET is_deleted_for_everyone = TRUE, 
          content = '🚫 This message was deleted', 
          attachment = NULL,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = $1
    `,
      [message_id]
    );

    // Broadcast deletion
    const io = req.app.get('io');
    if (io) {
      io.to(message.conversation_id).emit('message_deleted_for_everyone', {
        message_id,
        conversation_id: message.conversation_id,
      });
    }

    return res.json({ success: true, message: 'Message deleted for everyone successfully' });
  } catch (error) {
    console.error('Error in deleteForEveryone:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

/**
 * Delete for Me (Hides the message for the requesting user permanently)
 */
exports.deleteForMe = async (req, res) => {
  try {
    const { message_id, user_id } = req.body;

    if (!message_id || !user_id) {
      return res.status(400).json({ success: false, error: 'message_id and user_id are required' });
    }

    await db.query(
      `
      INSERT INTO community_message_deleted_users (message_id, user_id)
      VALUES ($1, $2)
      ON CONFLICT (message_id, user_id) DO NOTHING
    `,
      [message_id, user_id]
    );

    return res.json({ success: true, message: 'Message removed from your view' });
  } catch (error) {
    console.error('Error in deleteForMe:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};
