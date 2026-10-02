/**
 * RetailSale Business Community & Regional Chat Service (TypeScript)
 */

export interface CommunityMessagePayload {
  id?: string;
  conversation_id: string;
  sender_id: string;
  sender_name: string;
  sender_trade_name?: string;
  sender_city?: string;
  sender_gstin?: string;
  sender_phone?: string;
  content: string;
  attachment?: any;
}

export interface CreateConversationPayload {
  id?: string;
  title: string;
  description?: string;
  region_city?: string;
  region_state?: string;
  is_direct?: boolean;
  direct_recipient_id?: string;
  direct_recipient_name?: string;
  direct_recipient_gstin?: string;
  direct_recipient_phone?: string;
  direct_recipient_city?: string;
  creator_merchant_id?: string;
  creator_merchant_name?: string;
  creator_merchant_gstin?: string;
  creator_merchant_phone?: string;
  creator_merchant_city?: string;
}

let hasEnsuredColumns = false;
async function ensureCommunityColumns(db: any) {
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

      CREATE TABLE IF NOT EXISTS community_joined_channels (
        id SERIAL PRIMARY KEY,
        channel_id VARCHAR(100) NOT NULL,
        user_id VARCHAR(100) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(channel_id, user_id)
      );
    `);
    hasEnsuredColumns = true;
  } catch (err: any) {
    console.warn("Notice: ensureCommunityColumns:", err?.message);
  }
}

export async function getConversations(propertyDb: any, { city = 'New York', merchantId = '' }: { city?: string; merchantId?: string }) {
  await ensureCommunityColumns(propertyDb);
  const cleanCity = (city || 'New York').trim();

  // 1. Check if public channels exist for this city
  const [existingChannels] = await propertyDb.query(
    `SELECT id FROM community_conversations WHERE is_direct = FALSE AND LOWER(region_city) = LOWER(:city) LIMIT 1`,
    { replacements: { city: cleanCity } }
  );

  // Auto-seed real default regional trade hubs into PostgreSQL
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
      await propertyDb.query(
        `
        INSERT INTO community_conversations (id, title, description, region_city, region_state, is_direct, created_at, updated_at)
        VALUES (:id, :title, :description, :region_city, :region_state, :is_direct, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (id) DO NOTHING
      `,
        { replacements: ch }
      );
    }
  }

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
      (c.is_direct = FALSE AND (
         LOWER(c.region_city) = LOWER(:city)
         OR EXISTS (SELECT 1 FROM community_joined_channels jc WHERE jc.channel_id = c.id AND jc.user_id = :merchantId)
         OR c.creator_merchant_id = :merchantId
       ) AND NOT EXISTS (
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

  const [results] = await propertyDb.query(query, {
    replacements: {
      city: cleanCity,
      merchantWildcard: `%${merchantId}%`,
      merchantId: merchantId || '',
    },
  });

  const cleanReqId = String(merchantId || '').trim().toLowerCase();

  let defaultMaster = { property_name: 'REATILSHOP', gst_no: '', mobile: '', city: cleanCity };
  try {
    const [pRows] = await propertyDb.query(`SELECT property_name, legal_name, gst_no, mobile, city FROM property_info WHERE property_name IS NOT NULL AND property_name != '' LIMIT 1`);
    if (pRows && pRows.length > 0 && pRows[0].property_name) {
      defaultMaster = pRows[0];
    }
  } catch (_) {}

  const mappedResults = (results as any[]).map(row => {
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
  const seenDirectTitles = new Set<string>();
  const dedupedResults: any[] = [];

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
}

export async function createConversation(propertyDb: any, data: CreateConversationPayload) {
  await ensureCommunityColumns(propertyDb);
  const {
    id,
    title,
    description = '',
    region_city = 'New York',
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
  } = data as any;

  // Enforce 5 community channel limit per creator merchant
  if (!is_direct && creator_merchant_id) {
    const [countRows] = await propertyDb.query(`
      SELECT COUNT(*) as count FROM community_conversations 
      WHERE is_direct = FALSE AND (creator_merchant_id = :creator_merchant_id OR LOWER(creator_merchant_name) = LOWER(:creator_merchant_name))
    `, { replacements: { creator_merchant_id, creator_merchant_name: creator_merchant_name || '' } });
    const count = parseInt(countRows[0]?.count || '0', 10);
    if (count >= 5) {
      throw new Error('Community creation limit reached (maximum 5 communities per outlet)');
    }
  }

  try {
    await propertyDb.query(`
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

  const [rows] = await propertyDb.query(insertQuery, {
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
}

export async function discoverConversations(propertyDb: any, { query = '', state = '' }: { query?: string; state?: string }) {
  const cleanQ = query.trim();
  const searchQuery = `
    SELECT c.*,
      (SELECT COUNT(*) FROM community_messages m WHERE m.conversation_id = c.id) as message_count
    FROM community_conversations c
    WHERE c.is_direct = FALSE
      ${cleanQ ? "AND (LOWER(c.title) LIKE :q OR LOWER(c.description) LIKE :q OR LOWER(c.region_city) LIKE :q OR LOWER(c.id) LIKE :q)" : ""}
      ${state ? "AND LOWER(c.region_state) = LOWER(:state)" : ""}
    ORDER BY c.updated_at DESC
    LIMIT 5
  `;

  const [results] = await propertyDb.query(searchQuery, {
    replacements: {
      q: `%${cleanQ.toLowerCase()}%`,
      state,
    },
  });

  return results;
}

export async function getRegisteredMerchants(
  propertyDb: any, 
  { query = '', city = '', merchantId = '', limit = 30, offset = 0 }: { query?: string; city?: string; merchantId?: string; limit?: number; offset?: number }
) {
  const cleanQuery = (query || '').trim();
  const cleanCity = (city || '').trim();
  const cleanMerchantId = (merchantId || '').trim();

  const isSearchMode = cleanQuery.length > 0;
  const parsedLimit = isSearchMode ? 5 : Math.min(Math.max(Number(limit) || 30, 1), 100);
  const parsedOffset = isSearchMode ? 0 : Math.max(Number(offset) || 0, 0);

  // If neither query nor city is specified, fetch default property city
  let effectiveCity = cleanCity;
  if (!cleanQuery && !effectiveCity) {
    try {
      const [pRows] = await propertyDb.query(`SELECT city FROM property_info WHERE city IS NOT NULL AND city != '' LIMIT 1`);
      if (pRows && pRows.length > 0 && pRows[0].city) {
        effectiveCity = pRows[0].city;
      }
    } catch (_) {}
  }

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
      COALESCE(NULLIF(p.city, ''), 'New York') as city,
      COALESCE(p.state, '') as state,
      COALESCE(p.address, '') as address,
      COALESCE(o.outlet_type, 'STORE') as outlet_type,
      'PLATFORM_OUTLET' as merchant_type
    FROM outlets o
    LEFT JOIN property_info p ON (p.outlet_id = o.id OR p.id = o.id)
    WHERE o.is_active = TRUE
      ${cleanMerchantId ? "AND o.outlet_code != :merchantId AND o.id::text != :merchantId" : ""}
      ${effectiveCity && !isSearchMode ? "AND (LOWER(COALESCE(p.city, '')) = LOWER(:city) OR LOWER(COALESCE(p.city, '')) LIKE LOWER(:cityLike) OR LOWER(COALESCE(p.address, '')) LIKE LOWER(:cityLike))" : ""}
      ${isSearchMode ? "AND (LOWER(COALESCE(p.property_name, o.outlet_name, '')) LIKE :q OR LOWER(COALESCE(p.legal_name, '')) LIKE :q OR LOWER(COALESCE(p.gst_no, o.tax_id, '')) LIKE :q OR LOWER(COALESCE(p.city, '')) LIKE :q OR LOWER(COALESCE(p.address, '')) LIKE :q OR LOWER(o.outlet_code) LIKE :q OR LOWER(COALESCE(p.mobile, o.contact_phone, '')) LIKE :q)" : ""}
    ORDER BY o.id ASC
    LIMIT :limit OFFSET :offset
  `;

  const [results] = await propertyDb.query(sql, {
    replacements: {
      city: effectiveCity,
      cityLike: `%${effectiveCity}%`,
      merchantId: cleanMerchantId,
      q: `%${cleanQuery.toLowerCase()}%`,
      limit: parsedLimit,
      offset: parsedOffset,
    },
  });

  return results;
}

export async function getMessages(
  propertyDb: any,
  {
    conversationId,
    merchantId = '',
    limit = 50,
    offset = 0,
  }: {
    conversationId: string;
    merchantId?: string;
    limit?: number;
    offset?: number;
  }
) {
  const parsedLimit = Math.min(Math.max(Number(limit) || 50, 1), 100);
  const parsedOffset = Math.max(Number(offset) || 0, 0);

  let convIds: string[] = [conversationId];

  // For 1-on-1 direct chats, find all conversations exchanged between these two merchants
  if (conversationId.startsWith('direct_')) {
    try {
      const [cRows] = await propertyDb.query(
        `SELECT id, creator_merchant_id, direct_recipient_id FROM community_conversations WHERE id = :conversationId LIMIT 1`,
        { replacements: { conversationId } }
      );

      let p1 = '';
      let p2 = '';
      if (cRows && cRows.length > 0) {
        p1 = cRows[0].creator_merchant_id || '';
        p2 = cRows[0].direct_recipient_id || '';
      }

      if (!p1 || !p2) {
        // Fallback: extract outlet codes from direct ID (e.g. direct_CODE1_CODE2)
        const parts = conversationId.replace(/^direct_/, '').split('_');
        if (parts.length >= 2) {
          p1 = parts[0];
          p2 = parts[1];
        }
      }

      if (p1 && p2) {
        const [aliasRows] = await propertyDb.query(
          `SELECT DISTINCT id FROM community_conversations 
           WHERE is_direct = TRUE AND (
             (creator_merchant_id = :p1 AND direct_recipient_id = :p2)
             OR (creator_merchant_id = :p2 AND direct_recipient_id = :p1)
             OR (id = :convId)
             OR (id LIKE :like1 AND id LIKE :like2)
           )`,
          {
            replacements: {
              p1,
              p2,
              convId: conversationId,
              like1: `%${p1}%`,
              like2: `%${p2}%`,
            },
          }
        );
        if (aliasRows && aliasRows.length > 0) {
          convIds = Array.from(new Set(aliasRows.map((r: any) => r.id)));
        }
      }
    } catch (_) {}
  }

  const query = `
    WITH ordered_msgs AS (
      SELECT m.*, 
        COALESCE(json_agg(DISTINCT d.user_id) FILTER (WHERE d.user_id IS NOT NULL), '[]') as deleted_for_user_ids,
        COALESCE(json_agg(DISTINCT men.mentioned_handle) FILTER (WHERE men.mentioned_handle IS NOT NULL), '[]') as mentioned_handles
      FROM community_messages m
      LEFT JOIN community_message_deleted_users d ON m.id = d.message_id
      LEFT JOIN community_message_mentions men ON m.id = men.message_id
      WHERE m.conversation_id IN (:convIds)
        AND NOT EXISTS (
          SELECT 1 FROM community_message_deleted_users du 
          WHERE du.message_id = m.id AND du.user_id = :merchantId
        )
        AND NOT EXISTS (
          SELECT 1 FROM community_blocked_users bu
          WHERE bu.user_id = :merchantId AND bu.blocked_user_id = m.sender_id
        )
      GROUP BY m.id
      ORDER BY m.created_at DESC
      LIMIT :limit OFFSET :offset
    )
    SELECT * FROM ordered_msgs ORDER BY created_at ASC;
  `;

  const [results] = await propertyDb.query(query, {
    replacements: {
      convIds,
      merchantId,
      limit: parsedLimit,
      offset: parsedOffset,
    },
  });

  return results;
}

export async function sendMessage(propertyDb: any, messageData: CommunityMessagePayload) {
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
  const cleanCity = (sender_city || 'New York').trim();
  const autoTitle = isDirect
    ? 'Direct Merchant Chat'
    : `# ${conversation_id.replace(/^channel_/, '').replace(/_/g, ' ')}`;

  await propertyDb.query(
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

  const insertQuery = `
    INSERT INTO community_messages 
    (id, conversation_id, sender_id, sender_name, sender_trade_name, sender_city, sender_gstin, sender_phone, content, attachment, created_at)
    VALUES (:id, :conversation_id, :sender_id, :sender_name, :sender_trade_name, :sender_city, :sender_gstin, :sender_phone, :content, :attachment, CURRENT_TIMESTAMP)
    RETURNING *
  `;

  const [rows] = await propertyDb.query(insertQuery, {
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

  const mentionRegex = /@([a-zA-Z0-9_-]+)/g;
  let match: RegExpExecArray | null;
  const mentionedHandles: string[] = [];
  if (content) {
    while ((match = mentionRegex.exec(content)) !== null) {
      const handle = match[1];
      mentionedHandles.push(handle);
      await propertyDb.query(
        `INSERT INTO community_message_mentions (message_id, mentioned_handle) VALUES (:msgId, :handle)`,
        { replacements: { msgId, handle } }
      );
    }
  }

  await propertyDb.query(
    `UPDATE community_conversations SET updated_at = CURRENT_TIMESTAMP WHERE id = :conversation_id`,
    { replacements: { conversation_id } }
  );

  return {
    ...rows[0],
    mentioned_handles: mentionedHandles,
    deleted_for_user_ids: [],
  };
}

export async function deleteForEveryone(propertyDb: any, { messageId, senderId }: { messageId: string; senderId: string }) {
  const [rows] = await propertyDb.query(
    `SELECT * FROM community_messages WHERE id = :messageId`,
    { replacements: { messageId } }
  );

  if (!rows || rows.length === 0) {
    throw new Error('Message not found');
  }

  const message = rows[0];
  if (message.sender_id !== senderId) {
    throw new Error('You can only delete your own messages for everyone');
  }

  const diffHours = (Date.now() - new Date(message.created_at).getTime()) / (1000 * 60 * 60);
  if (diffHours >= 1) {
    throw new Error('Delete for everyone has expired (restricted to 1 hour)');
  }

  await propertyDb.query(
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
}

export async function editMessage(propertyDb: any, { messageId, senderId, content }: { messageId: string; senderId: string; content: string }) {
  const [rows] = await propertyDb.query(
    `SELECT * FROM community_messages WHERE id = :messageId`,
    { replacements: { messageId } }
  );

  if (!rows || rows.length === 0) {
    throw new Error('Message not found');
  }

  const message = rows[0];
  if (message.sender_id !== senderId) {
    throw new Error('You can only edit your own messages');
  }

  if (message.is_deleted_for_everyone) {
    throw new Error('Cannot edit a deleted message');
  }

  const diffHours = (Date.now() - new Date(message.created_at).getTime()) / (1000 * 60 * 60);
  if (diffHours >= 1) {
    throw new Error('Edit message has expired (restricted to 1 hour)');
  }

  await propertyDb.query(
    `
    UPDATE community_messages 
    SET content = :content, 
        updated_at = CURRENT_TIMESTAMP
    WHERE id = :messageId
  `,
    { replacements: { messageId, content } }
  );

  return { ...message, content };
}

export async function deleteForMe(propertyDb: any, { messageId, userId }: { messageId: string; userId: string }) {
  await propertyDb.query(
    `
    INSERT INTO community_message_deleted_users (message_id, user_id)
    VALUES (:messageId, :userId)
    ON CONFLICT (message_id, user_id) DO NOTHING
  `,
    { replacements: { messageId, userId } }
  );
  return true;
}

export async function blockUser(propertyDb: any, { userId, blockedUserId }: { userId: string; blockedUserId: string }) {
  await ensureCommunityColumns(propertyDb);
  await propertyDb.query(
    `
    INSERT INTO community_blocked_users (user_id, blocked_user_id)
    VALUES (:userId, :blockedUserId)
    ON CONFLICT (user_id, blocked_user_id) DO NOTHING
  `,
    { replacements: { userId, blockedUserId } }
  );
  return true;
}

export async function unblockUser(propertyDb: any, { userId, blockedUserId }: { userId: string; blockedUserId: string }) {
  await ensureCommunityColumns(propertyDb);
  await propertyDb.query(
    `
    DELETE FROM community_blocked_users
    WHERE user_id = :userId AND blocked_user_id = :blockedUserId
  `,
    { replacements: { userId, blockedUserId } }
  );
  return true;
}

export async function getBlockedUsers(propertyDb: any, { userId }: { userId: string }) {
  await ensureCommunityColumns(propertyDb);
  const [rows] = await propertyDb.query(
    `SELECT blocked_user_id FROM community_blocked_users WHERE user_id = :userId`,
    { replacements: { userId } }
  );
  return (rows as any[]).map(r => r.blocked_user_id);
}

export async function exitChannel(propertyDb: any, { channelId, userId }: { channelId: string; userId: string }) {
  await ensureCommunityColumns(propertyDb);
  // Remove from joined if present
  await propertyDb.query(
    `DELETE FROM community_joined_channels WHERE channel_id = :channelId AND user_id = :userId`,
    { replacements: { channelId, userId } }
  );
  await propertyDb.query(
    `
    INSERT INTO community_channel_exited_users (channel_id, user_id)
    VALUES (:channelId, :userId)
    ON CONFLICT (channel_id, user_id) DO NOTHING
  `,
    { replacements: { channelId, userId } }
  );
  return true;
}

export async function joinChannel(propertyDb: any, { channelId, userId }: { channelId: string; userId: string }) {
  await ensureCommunityColumns(propertyDb);
  // Remove from exited if present
  await propertyDb.query(
    `DELETE FROM community_channel_exited_users WHERE channel_id = :channelId AND user_id = :userId`,
    { replacements: { channelId, userId } }
  );
  // Add to joined
  await propertyDb.query(
    `
    INSERT INTO community_joined_channels (channel_id, user_id)
    VALUES (:channelId, :userId)
    ON CONFLICT (channel_id, user_id) DO NOTHING
  `,
    { replacements: { channelId, userId } }
  );
  return true;
}

export async function getJoinedChannels(propertyDb: any, { userId }: { userId: string }) {
  await ensureCommunityColumns(propertyDb);
  const [rows] = await propertyDb.query(
    `SELECT channel_id FROM community_joined_channels WHERE user_id = :userId`,
    { replacements: { userId } }
  );
  return (rows as any[]).map(r => r.channel_id);
}

export async function clearConversation(
  propertyDb: any,
  { conversationId, userId }: { conversationId: string; userId: string }
) {
  await ensureCommunityColumns(propertyDb);
  let convIds: string[] = [conversationId];

  if (conversationId.startsWith('direct_')) {
    try {
      const [cRows] = await propertyDb.query(
        `SELECT id, creator_merchant_id, direct_recipient_id FROM community_conversations WHERE id = :conversationId LIMIT 1`,
        { replacements: { conversationId } }
      );

      let p1 = '';
      let p2 = '';
      if (cRows && cRows.length > 0) {
        p1 = cRows[0].creator_merchant_id || '';
        p2 = cRows[0].direct_recipient_id || '';
      }

      if (!p1 || !p2) {
        const parts = conversationId.replace(/^direct_/, '').split('_');
        if (parts.length >= 2) {
          p1 = parts[0];
          p2 = parts[1];
        }
      }

      if (p1 && p2) {
        const [aliasRows] = await propertyDb.query(
          `SELECT DISTINCT id FROM community_conversations 
           WHERE is_direct = TRUE AND (
             (creator_merchant_id = :p1 AND direct_recipient_id = :p2)
             OR (creator_merchant_id = :p2 AND direct_recipient_id = :p1)
             OR (id = :convId)
             OR (id LIKE :like1 AND id LIKE :like2)
           )`,
          {
            replacements: {
              p1,
              p2,
              convId: conversationId,
              like1: `%${p1}%`,
              like2: `%${p2}%`,
            },
          }
        );
        if (aliasRows && aliasRows.length > 0) {
          convIds = Array.from(new Set(aliasRows.map((r: any) => r.id)));
        }
      }
    } catch (_) {}
  }

  // Insert into community_message_deleted_users for all existing messages in these conversation IDs
  await propertyDb.query(
    `
    INSERT INTO community_message_deleted_users (message_id, user_id)
    SELECT m.id, :userId 
    FROM community_messages m
    WHERE m.conversation_id IN (:convIds)
    ON CONFLICT (message_id, user_id) DO NOTHING
  `,
    {
      replacements: {
        convIds,
        userId,
      },
    }
  );

  return true;
}

