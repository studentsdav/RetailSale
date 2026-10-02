/**
 * RetailSale Business Community & Regional Chat Service
 * Supports PostgreSQL Sequelize / Raw Query execution
 */

function getDb(propertyDb) {
  return propertyDb;
}

let hasEnsuredColumns = false;
async function ensureCommunityColumns(db) {
  if (hasEnsuredColumns) return;
  try {
    await db.query(`
      ALTER TABLE community_conversations 
        ADD COLUMN IF NOT EXISTS creator_merchant_id VARCHAR(100) DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS creator_merchant_name VARCHAR(255) DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS creator_merchant_gstin VARCHAR(30) DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS creator_merchant_phone VARCHAR(30) DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS creator_merchant_city VARCHAR(100) DEFAULT NULL;

      CREATE TABLE IF NOT EXISTS community_blocked_users (
        id SERIAL PRIMARY KEY,
        user_id VARCHAR(100) NOT NULL,
        blocked_user_id VARCHAR(100) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, blocked_user_id)
      );

      CREATE TABLE IF NOT EXISTS community_channel_exited_users (
        id SERIAL PRIMARY KEY,
        channel_id VARCHAR(100) NOT NULL,
        user_id VARCHAR(100) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(channel_id, user_id)
      );
    `);
    hasEnsuredColumns = true;
  } catch (err) {
    console.warn("Notice: ensureCommunityColumns:", err?.message);
  }
}

/**
 * Get conversations for a merchant's region or direct chats
 * Auto-seeds initial regional database channels if none exist yet
 */
exports.getConversations = async (propertyDb, { city = 'Dehradun', merchantId = '' }) => {
  const db = getDb(propertyDb);
  await ensureCommunityColumns(db);
  const cleanCity = (city || 'Dehradun').trim();

  // 1. Check if any public channel exists for this city in the DB
  const [existingChannels] = await db.query(
    `SELECT id FROM community_conversations WHERE is_direct = FALSE AND LOWER(region_city) = LOWER(:city) LIMIT 1`,
    { replacements: { city: cleanCity } }
  );

  // If no channel exists in DB for this city, seed real default regional trade hubs
  if (!existingChannels || existingChannels.length === 0) {
    const citySlug = cleanCity.toLowerCase().replace(/[^a-z0-9]/g, '_');
    const defaultChannels = [
      {
        id: `channel_${citySlug}_hub`,
        title: `# ${cleanCity} Business & Retailers Hub`,
        description: `Open regional community network for all verified traders in ${cleanCity}`,
        region_city: cleanCity,
        region_state: '',
        is_direct: false,
      },
      {
        id: `channel_${citySlug}_b2b_trade`,
        title: `# ${cleanCity} B2B Wholesale & Stock Exchange`,
        description: 'Live bulk inventory requests, wholesale deals, and commodity trade',
        region_city: cleanCity,
        region_state: '',
        is_direct: false,
      },
      {
        id: `channel_${citySlug}_logistics`,
        title: `# ${cleanCity} Logistics & Fast Dispatch`,
        description: 'Delivery coordination, rider pooling, and same-day dispatch support',
        region_city: cleanCity,
        region_state: '',
        is_direct: false,
      },
    ];

    for (const ch of defaultChannels) {
      await db.query(
        `
        INSERT INTO community_conversations (id, title, description, region_city, region_state, is_direct, created_at, updated_at)
        VALUES (:id, :title, :description, :region_city, :region_state, :is_direct, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (id) DO NOTHING
      `,
        { replacements: ch }
      );
    }
  }

  // 2. Query regional channels + direct conversations
  const query = `
    SELECT c.*, 
      (
        SELECT json_build_object(
          'id', m.id, 
          'content', m.content, 
          'sender_id', m.sender_id,
          'sender_name', m.sender_name, 
          'sender_gstin', m.sender_gstin,
          'created_at', m.created_at, 
          'is_deleted_for_everyone', m.is_deleted_for_everyone
        ) 
        FROM community_messages m 
        WHERE m.conversation_id = c.id 
        ORDER BY m.created_at DESC 
        LIMIT 1
      ) as last_message,
      (
        SELECT COUNT(*)
        FROM community_messages m
        WHERE m.conversation_id = c.id
          AND m.sender_id != :merchantId
          AND NOT EXISTS (
            SELECT 1 FROM community_message_deleted_users du
            WHERE du.message_id = m.id AND du.user_id = :merchantId
          )
          AND NOT EXISTS (
            SELECT 1 FROM community_blocked_users bu
            WHERE bu.user_id = :merchantId AND bu.blocked_user_id = m.sender_id
          )
      ) as unread_count
    FROM community_conversations c
    WHERE (
      (c.is_direct = FALSE AND LOWER(c.region_city) = LOWER(:city) AND NOT EXISTS (
        SELECT 1 FROM community_channel_exited_users ex WHERE ex.channel_id = c.id AND ex.user_id = :merchantId
      ))
      OR (c.is_direct = TRUE AND (
            c.id LIKE :merchantWildcard 
         OR c.direct_recipient_id = :merchantId 
         OR c.creator_merchant_id = :merchantId
         OR EXISTS (SELECT 1 FROM community_messages m WHERE m.conversation_id = c.id AND m.sender_id = :merchantId)
       ))
    )
    ORDER BY c.updated_at DESC
  `;

  const [results] = await db.query(query, {
    replacements: {
      city: cleanCity,
      merchantWildcard: `%${merchantId}%`,
      merchantId: merchantId || '',
    },
  });

  const cleanReqId = String(merchantId || '').trim().toLowerCase();

  // Load default property info for fallback (e.g. Master headquarters / registered property name)
  let defaultMaster = { property_name: 'REATILSHOP', gst_no: '', mobile: '', city: cleanCity };
  try {
    const [pRows] = await db.query(`SELECT property_name, legal_name, gst_no, mobile, city FROM property_info WHERE property_name IS NOT NULL AND property_name != '' LIMIT 1`);
    if (pRows && pRows.length > 0 && pRows[0].property_name) {
      defaultMaster = pRows[0];
    }
  } catch (_) {}

  const mappedResults = results.map(row => {
    if (row.is_direct) {
      const recId = String(row.direct_recipient_id || '').trim().toLowerCase();
      const recName = String(row.direct_recipient_name || '').trim().toLowerCase();
      const creatorId = String(row.creator_merchant_id || '').trim().toLowerCase();
      const creatorName = String(row.creator_merchant_name || '').trim().toLowerCase();
      const rowTitle = String(row.title || '').replace(/^#\s*/, '').trim();

      let counterpartTitle = '';
      let counterpartId = null;
      let counterpartGstin = null;
      let counterpartPhone = null;
      let counterpartCity = null;

      // 1. If requesting user is recipient
      if (cleanReqId && (cleanReqId === recId || (recName && cleanReqId === recName))) {
        counterpartTitle = row.creator_merchant_name || defaultMaster.property_name || rowTitle;
        counterpartId = row.creator_merchant_id;
        counterpartGstin = row.creator_merchant_gstin || defaultMaster.gst_no;
        counterpartPhone = row.creator_merchant_phone || defaultMaster.mobile;
        counterpartCity = row.creator_merchant_city || defaultMaster.city;
      }
      // 2. If requesting user is creator
      else if (cleanReqId && (cleanReqId === creatorId || (creatorName && cleanReqId === creatorName))) {
        counterpartTitle = row.direct_recipient_name || rowTitle || 'Business Partner';
        counterpartId = row.direct_recipient_id;
        counterpartGstin = row.direct_recipient_gstin;
        counterpartPhone = row.direct_recipient_phone;
        counterpartCity = row.direct_recipient_city;
      }
      // 3. Fallback: check if rowTitle or direct_recipient_name equals requesting user's identity
      else if (cleanReqId && (rowTitle.toLowerCase() === cleanReqId || recName === cleanReqId)) {
        counterpartTitle = row.creator_merchant_name || defaultMaster.property_name || 'Business Partner';
        counterpartId = row.creator_merchant_id;
        counterpartGstin = row.creator_merchant_gstin || defaultMaster.gst_no;
        counterpartPhone = row.creator_merchant_phone || defaultMaster.mobile;
        counterpartCity = row.creator_merchant_city || defaultMaster.city;
      } else {
        counterpartTitle = row.direct_recipient_name || rowTitle || 'Business Partner';
        counterpartId = row.direct_recipient_id;
        counterpartGstin = row.direct_recipient_gstin;
        counterpartPhone = row.direct_recipient_phone;
        counterpartCity = row.direct_recipient_city;
      }

      // Safety check: Never show requesting user's own name as the counterpart!
      if (cleanReqId && counterpartTitle.toLowerCase() === cleanReqId) {
        if (row.creator_merchant_name && row.creator_merchant_name.toLowerCase() !== cleanReqId) {
          counterpartTitle = row.creator_merchant_name;
        } else if (defaultMaster.property_name && defaultMaster.property_name.toLowerCase() !== cleanReqId) {
          counterpartTitle = defaultMaster.property_name;
        } else {
          counterpartTitle = 'Business Partner';
        }
      }

      return {
        ...row,
        title: counterpartTitle.replace(/^#\s*/, '').trim(),
        direct_recipient_id: counterpartId,
        direct_recipient_name: counterpartTitle.replace(/^#\s*/, '').trim(),
        direct_recipient_gstin: counterpartGstin,
        direct_recipient_phone: counterpartPhone,
        direct_recipient_city: counterpartCity,
      };
    }
    return row;
  });

  // Deduplicate direct chats so only ONE thread per business counterpart appears
  const seenDirectTitles = new Set();
  const dedupedResults = [];

  for (const conv of mappedResults) {
    if (conv.is_direct) {
      const cleanKey = conv.title.toLowerCase().replace(/[^a-z0-9]/g, '');
      if (seenDirectTitles.has(cleanKey)) {
        continue;
      }
      seenDirectTitles.add(cleanKey);
      dedupedResults.push(conv);
    } else {
      dedupedResults.push(conv);
    }
  }

  return dedupedResults;
};

/**
 * Create a new Real Community Channel or Direct Thread
 */
exports.createConversation = async (propertyDb, data) => {
  const db = getDb(propertyDb);
  await ensureCommunityColumns(db);
  const {
    id,
    title,
    description = '',
    region_city = 'Dehradun',
    region_state = '',
    is_direct = false,
    creator_merchant_id = null,
    creator_merchant_name = null,
    creator_merchant_gstin = null,
    creator_merchant_phone = null,
    creator_merchant_city = null,
    direct_recipient_id = null,
    direct_recipient_name = null,
    direct_recipient_gstin = null,
    direct_recipient_phone = null,
    direct_recipient_city = null,
  } = data;

  try {
    await db.query(`
      ALTER TABLE community_conversations 
        ADD COLUMN IF NOT EXISTS creator_merchant_id VARCHAR(100) DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS creator_merchant_name VARCHAR(255) DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS creator_merchant_gstin VARCHAR(30) DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS creator_merchant_phone VARCHAR(30) DEFAULT NULL,
        ADD COLUMN IF NOT EXISTS creator_merchant_city VARCHAR(100) DEFAULT NULL;
    `);
  } catch (_) {}

  const convId =
    id ||
    (is_direct
      ? `direct_${Date.now()}_${Math.floor(Math.random() * 1000)}`
      : `channel_${region_city.toLowerCase().replace(/[^a-z0-9]/g, '_')}_${Date.now()}`);

  const formattedTitle = is_direct
    ? title.replace(/^#\s*/, '').trim()
    : (title.startsWith('#') ? title.trim() : `# ${title.trim()}`);

  const insertQuery = `
    INSERT INTO community_conversations 
    (id, title, description, region_city, region_state, is_direct, 
     creator_merchant_id, creator_merchant_name, creator_merchant_gstin, creator_merchant_phone, creator_merchant_city,
     direct_recipient_id, direct_recipient_name, direct_recipient_gstin, direct_recipient_phone, direct_recipient_city, 
     created_at, updated_at)
    VALUES (:id, :title, :description, :region_city, :region_state, :is_direct, 
            :creator_merchant_id, :creator_merchant_name, :creator_merchant_gstin, :creator_merchant_phone, :creator_merchant_city,
            :direct_recipient_id, :direct_recipient_name, :direct_recipient_gstin, :direct_recipient_phone, :direct_recipient_city, 
            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT (id) DO UPDATE 
    SET title = EXCLUDED.title, 
        description = EXCLUDED.description, 
        creator_merchant_id = COALESCE(community_conversations.creator_merchant_id, EXCLUDED.creator_merchant_id),
        creator_merchant_name = COALESCE(community_conversations.creator_merchant_name, EXCLUDED.creator_merchant_name),
        creator_merchant_gstin = COALESCE(community_conversations.creator_merchant_gstin, EXCLUDED.creator_merchant_gstin),
        creator_merchant_phone = COALESCE(community_conversations.creator_merchant_phone, EXCLUDED.creator_merchant_phone),
        creator_merchant_city = COALESCE(community_conversations.creator_merchant_city, EXCLUDED.creator_merchant_city),
        direct_recipient_id = COALESCE(community_conversations.direct_recipient_id, EXCLUDED.direct_recipient_id),
        direct_recipient_name = COALESCE(community_conversations.direct_recipient_name, EXCLUDED.direct_recipient_name),
        direct_recipient_gstin = COALESCE(community_conversations.direct_recipient_gstin, EXCLUDED.direct_recipient_gstin),
        direct_recipient_phone = COALESCE(community_conversations.direct_recipient_phone, EXCLUDED.direct_recipient_phone),
        direct_recipient_city = COALESCE(community_conversations.direct_recipient_city, EXCLUDED.direct_recipient_city),
        updated_at = CURRENT_TIMESTAMP
    RETURNING *
  `;

  const [rows] = await db.query(insertQuery, {
    replacements: {
      id: convId,
      title: formattedTitle,
      description,
      region_city,
      region_state,
      is_direct,
      creator_merchant_id,
      creator_merchant_name,
      creator_merchant_gstin,
      creator_merchant_phone,
      creator_merchant_city,
      direct_recipient_id,
      direct_recipient_name,
      direct_recipient_gstin,
      direct_recipient_phone,
      direct_recipient_city,
    },
  });

  return rows[0];
};

/**
 * Discover public community channels across all regions
 */
exports.discoverConversations = async (propertyDb, { query = '', state = '' }) => {
  const db = getDb(propertyDb);
  const searchQuery = `
    SELECT c.*,
      (SELECT COUNT(*) FROM community_messages m WHERE m.conversation_id = c.id) as message_count
    FROM community_conversations c
    WHERE c.is_direct = FALSE
      ${query ? "AND (LOWER(c.title) LIKE :q OR LOWER(c.description) LIKE :q OR LOWER(c.region_city) LIKE :q)" : ""}
      ${state ? "AND LOWER(c.region_state) = LOWER(:state)" : ""}
    ORDER BY c.updated_at DESC
    LIMIT 50
  `;

  const [results] = await db.query(searchQuery, {
    replacements: {
      q: `%${query.toLowerCase()}%`,
      state,
    },
  });

  return results;
};

/**
 * Get all registered platform businesses & outlets from outlets and property_info
 */
exports.getRegisteredMerchants = async (propertyDb, { query = '', city = '' }) => {
  const db = getDb(propertyDb);
  const sql = `
    SELECT 
      o.outlet_code as id,
      o.id as outlet_id,
      o.outlet_code,
      COALESCE(NULLIF(p.property_name, ''), o.outlet_name, 'Outlet ' || o.id) as business_name,
      COALESCE(NULLIF(p.legal_name, ''), p.property_name, o.outlet_name, '') as trade_name,
      COALESCE(p.gst_no, o.tax_id, '') as gstin,
      COALESCE(p.mobile, o.contact_phone, '') as phone,
      COALESCE(p.email, o.contact_email, '') as email,
      COALESCE(p.city, '') as city,
      COALESCE(p.state, '') as state,
      COALESCE(p.address, '') as address,
      COALESCE(o.outlet_type, 'STORE') as outlet_type,
      'PLATFORM_OUTLET' as merchant_type
    FROM outlets o
    LEFT JOIN property_info p ON (p.outlet_id = o.id OR p.id = o.id)
    WHERE o.is_active = TRUE
      ${query ? "AND (LOWER(COALESCE(p.property_name, o.outlet_name, '')) LIKE :q OR LOWER(COALESCE(p.gst_no, o.tax_id, '')) LIKE :q OR LOWER(COALESCE(p.city, '')) LIKE :q)" : ""}
    ORDER BY o.id ASC
  `;

  const [results] = await db.query(sql, {
    replacements: {
      q: `%${query.toLowerCase()}%`,
    },
  });

  return results;
};

exports.getMessages = async (propertyDb, { conversationId, merchantId = '' }) => {
  const db = getDb(propertyDb);
  const query = `
    SELECT m.*, 
      COALESCE(json_agg(DISTINCT d.user_id) FILTER (WHERE d.user_id IS NOT NULL), '[]') as deleted_for_user_ids,
      COALESCE(json_agg(DISTINCT men.mentioned_handle) FILTER (WHERE men.mentioned_handle IS NOT NULL), '[]') as mentioned_handles
    FROM community_messages m
    LEFT JOIN community_message_deleted_users d ON m.id = d.message_id
    LEFT JOIN community_message_mentions men ON m.id = men.message_id
    WHERE m.conversation_id = :conversationId
      AND NOT EXISTS (
        SELECT 1 FROM community_message_deleted_users du 
        WHERE du.message_id = m.id AND du.user_id = :merchantId
      )
      AND NOT EXISTS (
        SELECT 1 FROM community_blocked_users bu
        WHERE bu.user_id = :merchantId AND bu.blocked_user_id = m.sender_id
      )
    GROUP BY m.id
    ORDER BY m.created_at ASC
  `;

  const [results] = await db.query(query, {
    replacements: {
      conversationId,
      merchantId,
    },
  });

  return results;
};

exports.sendMessage = async (propertyDb, messageData) => {
  const db = getDb(propertyDb);
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
  } = messageData;

  const msgId = id || `msg_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

  // 0. Ensure conversation exists in community_conversations table (Foreign Key safety)
  const isDirect = conversation_id.startsWith('direct_');
  const cleanCity = (sender_city || 'Dehradun').trim();
  const autoTitle = isDirect
    ? 'Direct Merchant Chat'
    : `# ${conversation_id.replace(/^channel_/, '').replace(/_/g, ' ')}`;

  await db.query(
    `
    INSERT INTO community_conversations 
    (id, title, description, region_city, region_state, is_direct, created_at, updated_at)
    VALUES (:conversation_id, :autoTitle, '', :cleanCity, '', :isDirect, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT (id) DO UPDATE SET updated_at = CURRENT_TIMESTAMP
  `,
    {
      replacements: {
        conversation_id,
        autoTitle,
        cleanCity,
        isDirect,
      },
    }
  );

  // 1. Insert message
  const insertQuery = `
    INSERT INTO community_messages 
    (id, conversation_id, sender_id, sender_name, sender_trade_name, sender_city, sender_gstin, sender_phone, content, attachment, created_at)
    VALUES (:id, :conversation_id, :sender_id, :sender_name, :sender_trade_name, :sender_city, :sender_gstin, :sender_phone, :content, :attachment, CURRENT_TIMESTAMP)
    RETURNING *
  `;

  const [rows] = await db.query(insertQuery, {
    replacements: {
      id: msgId,
      conversation_id,
      sender_id,
      sender_name,
      sender_trade_name,
      sender_city,
      sender_gstin,
      sender_phone,
      content: content || '',
      attachment: attachment ? JSON.stringify(attachment) : null,
    },
  });

  // 2. Parse @mentions
  const mentionRegex = /@([a-zA-Z0-9_-]+)/g;
  let match;
  const mentionedHandles = [];
  if (content) {
    while ((match = mentionRegex.exec(content)) !== null) {
      const handle = match[1];
      mentionedHandles.push(handle);
      await db.query(
        `INSERT INTO community_message_mentions (message_id, mentioned_handle) VALUES (:msgId, :handle)`,
        { replacements: { msgId, handle } }
      );
    }
  }

  // 3. Update Conversation updated_at
  await db.query(
    `UPDATE community_conversations SET updated_at = CURRENT_TIMESTAMP WHERE id = :conversation_id`,
    { replacements: { conversation_id } }
  );

  return {
    ...rows[0],
    mentioned_handles: mentionedHandles,
    deleted_for_user_ids: [],
  };
};

exports.deleteForEveryone = async (propertyDb, { messageId, senderId }) => {
  const db = getDb(propertyDb);

  const [rows] = await db.query(
    `SELECT * FROM community_messages WHERE id = :messageId`,
    { replacements: { messageId } }
  );

  if (rows.length === 0) {
    throw new Error('Message not found');
  }

  const message = rows[0];
  if (message.sender_id !== senderId) {
    throw new Error('You can only delete your own messages for everyone');
  }

  const diffHours = (Date.now() - new Date(message.created_at).getTime()) / (1000 * 60 * 60);
  if (diffHours >= 2) {
    throw new Error('Delete for everyone has expired (restricted to 2 hours)');
  }

  await db.query(
    `
    UPDATE community_messages 
    SET is_deleted_for_everyone = TRUE, 
        content = '🚫 This message was deleted', 
        attachment = NULL,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = :messageId
  `,
    { replacements: { messageId } }
  );

  return message;
};

exports.deleteForMe = async (propertyDb, { messageId, userId }) => {
  const db = getDb(propertyDb);
  await db.query(
    `
    INSERT INTO community_message_deleted_users (message_id, user_id)
    VALUES (:messageId, :userId)
    ON CONFLICT (message_id, user_id) DO NOTHING
  `,
    { replacements: { messageId, userId } }
  );
  return true;
};

exports.blockUser = async (propertyDb, { userId, blockedUserId }) => {
  const db = getDb(propertyDb);
  await ensureCommunityColumns(db);
  await db.query(
    `
    INSERT INTO community_blocked_users (user_id, blocked_user_id)
    VALUES (:userId, :blockedUserId)
    ON CONFLICT (user_id, blocked_user_id) DO NOTHING
  `,
    { replacements: { userId, blockedUserId } }
  );
  return true;
};

exports.unblockUser = async (propertyDb, { userId, blockedUserId }) => {
  const db = getDb(propertyDb);
  await ensureCommunityColumns(db);
  await db.query(
    `
    DELETE FROM community_blocked_users
    WHERE user_id = :userId AND blocked_user_id = :blockedUserId
  `,
    { replacements: { userId, blockedUserId } }
  );
  return true;
};

exports.getBlockedUsers = async (propertyDb, { userId }) => {
  const db = getDb(propertyDb);
  await ensureCommunityColumns(db);
  const [rows] = await db.query(
    `SELECT blocked_user_id FROM community_blocked_users WHERE user_id = :userId`,
    { replacements: { userId } }
  );
  return (rows || []).map(r => r.blocked_user_id);
};

exports.exitChannel = async (propertyDb, { channelId, userId }) => {
  const db = getDb(propertyDb);
  await ensureCommunityColumns(db);
  await db.query(
    `
    INSERT INTO community_channel_exited_users (channel_id, user_id)
    VALUES (:channelId, :userId)
    ON CONFLICT (channel_id, user_id) DO NOTHING
  `,
    { replacements: { channelId, userId } }
  );
  return true;
};
