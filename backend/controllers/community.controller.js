const communityService = require('../services/community.service');

exports.createConversation = async (req, res) => {
  try {
    const conversation = await communityService.createConversation(req.propertyDb, req.body);
    const io = req.app.get('io');
    if (io) {
      io.emit('new_channel', conversation);
    }
    return res.status(201).json({ success: true, data: conversation });
  } catch (error) {
    console.error('[COMMUNITY CREATE CONVERSATION ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

exports.discoverConversations = async (req, res) => {
  try {
    const { q, state } = req.query;
    const channels = await communityService.discoverConversations(req.propertyDb, {
      query: q || '',
      state: state || '',
    });
    return res.json({ success: true, data: channels });
  } catch (error) {
    console.error('[COMMUNITY DISCOVER CHANNELS ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

exports.getMerchants = async (req, res) => {
  try {
    const { q, city } = req.query;
    const merchants = await communityService.getRegisteredMerchants(req.propertyDb, {
      query: q || '',
      city: city || '',
    });
    return res.json({ success: true, data: merchants });
  } catch (error) {
    console.error('[COMMUNITY GET MERCHANTS ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

exports.getConversations = async (req, res) => {
  try {
    const { city, merchant_id } = req.query;
    const conversations = await communityService.getConversations(req.propertyDb, {
      city: city || 'Dehradun',
      merchantId: merchant_id || '',
    });
    return res.json({ success: true, data: conversations });
  } catch (error) {
    console.error('[COMMUNITY GET CONVERSATIONS ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

exports.getMessages = async (req, res) => {
  try {
    const { conversation_id, merchant_id } = req.query;
    if (!conversation_id) {
      return res.status(400).json({ success: false, message: 'conversation_id is required' });
    }
    const messages = await communityService.getMessages(req.propertyDb, {
      conversationId: conversation_id,
      merchantId: merchant_id || '',
    });
    return res.json({ success: true, data: messages });
  } catch (error) {
    console.error('[COMMUNITY GET MESSAGES ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

exports.sendMessage = async (req, res) => {
  try {
    const message = await communityService.sendMessage(req.propertyDb, req.body);

    // Live socket broadcast
    const io = req.app.get('io');
    if (io && req.body.conversation_id) {
      io.to(req.body.conversation_id).emit('new_message', message);
    }

    return res.status(201).json({ success: true, data: message });
  } catch (error) {
    console.error('[COMMUNITY SEND MESSAGE ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

exports.deleteForEveryone = async (req, res) => {
  try {
    const { message_id, sender_id } = req.body;
    if (!message_id || !sender_id) {
      return res.status(400).json({ success: false, message: 'message_id and sender_id are required' });
    }

    const message = await communityService.deleteForEveryone(req.propertyDb, {
      messageId: message_id,
      senderId: sender_id,
    });

    const io = req.app.get('io');
    if (io && message.conversation_id) {
      io.to(message.conversation_id).emit('message_deleted_for_everyone', {
        message_id,
        conversation_id: message.conversation_id,
      });
    }

    return res.json({ success: true, message: 'Message deleted for everyone', data: message });
  } catch (error) {
    console.error('[COMMUNITY DELETE FOR EVERYONE ERROR]:', error.message);
    const status = error.message.includes('expired') ? 400 : error.message.includes('own') ? 403 : 500;
    return res.status(status).json({ success: false, message: error.message });
  }
};

exports.deleteForMe = async (req, res) => {
  try {
    const { message_id, user_id } = req.body;
    if (!message_id || !user_id) {
      return res.status(400).json({ success: false, message: 'message_id and user_id are required' });
    }

    await communityService.deleteForMe(req.propertyDb, {
      messageId: message_id,
      userId: user_id,
    });

    return res.json({ success: true, message: 'Message deleted from your view' });
  } catch (error) {
    console.error('[COMMUNITY DELETE FOR ME ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

exports.blockUser = async (req, res) => {
  try {
    const { user_id, blocked_user_id } = req.body;
    if (!user_id || !blocked_user_id) {
      return res.status(400).json({ success: false, message: 'user_id and blocked_user_id are required' });
    }

    await communityService.blockUser(req.propertyDb, {
      userId: user_id,
      blockedUserId: blocked_user_id,
    });

    return res.json({ success: true, message: 'Merchant blocked successfully' });
  } catch (error) {
    console.error('[COMMUNITY BLOCK ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

exports.unblockUser = async (req, res) => {
  try {
    const { user_id, blocked_user_id } = req.body;
    if (!user_id || !blocked_user_id) {
      return res.status(400).json({ success: false, message: 'user_id and blocked_user_id are required' });
    }

    await communityService.unblockUser(req.propertyDb, {
      userId: user_id,
      blockedUserId: blocked_user_id,
    });

    return res.json({ success: true, message: 'Merchant unblocked successfully' });
  } catch (error) {
    console.error('[COMMUNITY UNBLOCK ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

exports.getBlockedUsers = async (req, res) => {
  try {
    const { user_id } = req.query;
    if (!user_id) {
      return res.status(400).json({ success: false, message: 'user_id is required' });
    }

    const blockedList = await communityService.getBlockedUsers(req.propertyDb, {
      userId: user_id,
    });

    return res.json({ success: true, data: blockedList });
  } catch (error) {
    console.error('[COMMUNITY GET BLOCKED ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};

exports.exitChannel = async (req, res) => {
  try {
    const { channel_id, user_id } = req.body;
    if (!channel_id || !user_id) {
      return res.status(400).json({ success: false, message: 'channel_id and user_id are required' });
    }

    await communityService.exitChannel(req.propertyDb, {
      channelId: channel_id,
      userId: user_id,
    });

    return res.json({ success: true, message: 'Exited community channel successfully' });
  } catch (error) {
    console.error('[COMMUNITY EXIT CHANNEL ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
};
