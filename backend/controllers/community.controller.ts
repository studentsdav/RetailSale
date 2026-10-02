import { Request, Response } from 'express';
import * as communityService from '../services/community.service';

export async function createConversation(req: any, res: Response) {
  try {
    const conversation = await communityService.createConversation(req.propertyDb, req.body);
    const io = req.app.get('io');
    if (io) {
      io.emit('new_channel', conversation);
    }
    return res.status(201).json({ success: true, data: conversation });
  } catch (error: any) {
    console.error('[COMMUNITY CREATE CONVERSATION ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function discoverConversations(req: any, res: Response) {
  try {
    const { q, state } = req.query as { q?: string; state?: string };
    const channels = await communityService.discoverConversations(req.propertyDb, {
      query: q || '',
      state: state || '',
    });
    return res.json({ success: true, data: channels });
  } catch (error: any) {
    console.error('[COMMUNITY DISCOVER CHANNELS ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function getMerchants(req: any, res: Response) {
  try {
    const { q, city, merchant_id, limit, offset } = req.query as { q?: string; city?: string; merchant_id?: string; limit?: string; offset?: string };
    const merchants = await communityService.getRegisteredMerchants(req.propertyDb, {
      query: q || '',
      city: city || '',
      merchantId: merchant_id || req.user?.outlet_code || '',
      limit: limit ? Number(limit) : undefined,
      offset: offset ? Number(offset) : undefined,
    });
    return res.json({ success: true, data: merchants });
  } catch (error: any) {
    console.error('[COMMUNITY GET MERCHANTS ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function getConversations(req: any, res: Response) {
  try {
    const { city, merchant_id } = req.query as { city?: string; merchant_id?: string };
    const conversations = await communityService.getConversations(req.propertyDb, {
      city: city || 'Dehradun',
      merchantId: merchant_id || '',
    });
    return res.json({ success: true, data: conversations });
  } catch (error: any) {
    console.error('[COMMUNITY GET CONVERSATIONS ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function getMessages(req: any, res: Response) {
  try {
    const { conversation_id, merchant_id } = req.query as { conversation_id: string; merchant_id?: string };
    if (!conversation_id) {
      return res.status(400).json({ success: false, message: 'conversation_id is required' });
    }
    const messages = await communityService.getMessages(req.propertyDb, {
      conversationId: conversation_id,
      merchantId: merchant_id || '',
    });
    return res.json({ success: true, data: messages });
  } catch (error: any) {
    console.error('[COMMUNITY GET MESSAGES ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function sendMessage(req: any, res: Response) {
  try {
    const message = await communityService.sendMessage(req.propertyDb, req.body);

    const io = req.app.get('io');
    if (io && req.body.conversation_id) {
      io.to(req.body.conversation_id).emit('new_message', message);
    }

    return res.status(201).json({ success: true, data: message });
  } catch (error: any) {
    console.error('[COMMUNITY SEND MESSAGE ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function deleteForEveryone(req: any, res: Response) {
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
  } catch (error: any) {
    console.error('[COMMUNITY DELETE FOR EVERYONE ERROR]:', error.message);
    const status = error.message.includes('expired') ? 400 : error.message.includes('own') ? 403 : 500;
    return res.status(status).json({ success: false, message: error.message });
  }
}

export async function editMessage(req: any, res: Response) {
  try {
    const { message_id, content, sender_id } = req.body;
    const msgId = req.params.id || message_id;
    if (!msgId || !content) {
      return res.status(400).json({ success: false, message: 'message_id and content are required' });
    }

    const updated = await communityService.editMessage(req.propertyDb, {
      messageId: msgId,
      senderId: sender_id || req.user?.outlet_code || req.user?.id,
      content,
    });

    const socketService = req.app.get('socketService');
    if (socketService) {
      socketService.emitToCommunity(updated.conversation_id, 'community:message_edited', {
        message_id: msgId,
        conversation_id: updated.conversation_id,
        content,
      });
    }

    return res.json({ success: true, message: 'Message edited successfully', data: updated });
  } catch (error: any) {
    console.error('[COMMUNITY EDIT MESSAGE ERROR]:', error.message);
    const status = error.message.includes('expired') ? 400 : error.message.includes('own') ? 403 : 500;
    return res.status(status).json({ success: false, message: error.message });
  }
}

export async function deleteForMe(req: any, res: Response) {
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
  } catch (error: any) {
    console.error('[COMMUNITY DELETE FOR ME ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function blockUser(req: any, res: Response) {
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
  } catch (error: any) {
    console.error('[COMMUNITY BLOCK ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function unblockUser(req: any, res: Response) {
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
  } catch (error: any) {
    console.error('[COMMUNITY UNBLOCK ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function getBlockedUsers(req: any, res: Response) {
  try {
    const { user_id } = req.query as { user_id?: string };
    if (!user_id) {
      return res.status(400).json({ success: false, message: 'user_id is required' });
    }

    const blockedList = await communityService.getBlockedUsers(req.propertyDb, {
      userId: user_id,
    });

    return res.json({ success: true, data: blockedList });
  } catch (error: any) {
    console.error('[COMMUNITY GET BLOCKED ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function exitChannel(req: any, res: Response) {
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
  } catch (error: any) {
    console.error('[COMMUNITY EXIT CHANNEL ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function joinChannel(req: any, res: Response) {
  try {
    const { channel_id, user_id } = req.body;
    if (!channel_id || !user_id) {
      return res.status(400).json({ success: false, message: 'channel_id and user_id are required' });
    }

    await communityService.joinChannel(req.propertyDb, {
      channelId: channel_id,
      userId: user_id,
    });

    return res.json({ success: true, message: 'Joined community channel successfully' });
  } catch (error: any) {
    console.error('[COMMUNITY JOIN CHANNEL ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

export async function clearConversation(req: any, res: Response) {
  try {
    const { conversation_id, user_id } = req.body;
    if (!conversation_id || !user_id) {
      return res.status(400).json({ success: false, message: 'conversation_id and user_id are required' });
    }

    await communityService.clearConversation(req.propertyDb, {
      conversationId: conversation_id,
      userId: user_id,
    });

    return res.json({ success: true, message: 'Chat cleared successfully' });
  } catch (error: any) {
    console.error('[COMMUNITY CLEAR CONVERSATION ERROR]:', error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

