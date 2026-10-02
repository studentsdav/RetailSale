import { Request, Response } from 'express';
import { CommunityService } from './community.service';
import { SendMessageDto, DeleteForEveryoneDto, DeleteForMeDto } from './community.types';

const communityService = new CommunityService();

export class CommunityController {
  async getConversations(req: Request, res: Response) {
    try {
      const { city, merchant_id } = req.query as { city?: string; merchant_id?: string };
      const data = await communityService.getConversations(city || 'Dehradun', merchant_id);
      return res.json({ success: true, data });
    } catch (error: any) {
      return res.status(500).json({ success: false, error: error.message });
    }
  }

  async getMessages(req: Request, res: Response) {
    try {
      const { conversation_id, merchant_id } = req.query as { conversation_id: string; merchant_id?: string };
      if (!conversation_id) {
        return res.status(400).json({ success: false, error: 'conversation_id is required' });
      }
      const data = await communityService.getMessages(conversation_id, merchant_id);
      return res.json({ success: true, data });
    } catch (error: any) {
      return res.status(500).json({ success: false, error: error.message });
    }
  }

  async sendMessage(req: Request, res: Response) {
    try {
      const dto: SendMessageDto = req.body;
      if (!dto.content && !dto.attachment) {
        return res.status(400).json({ success: false, error: 'Message content or attachment is required' });
      }

      const data = await communityService.sendMessage(dto);

      // Broadcast live event via Socket.IO
      const io = req.app.get('io');
      if (io) {
        io.to(dto.conversation_id).emit('new_message', data);
      }

      return res.status(201).json({ success: true, data });
    } catch (error: any) {
      return res.status(500).json({ success: false, error: error.message });
    }
  }

  async deleteForEveryone(req: Request, res: Response) {
    try {
      const dto: DeleteForEveryoneDto = req.body;
      const data = await communityService.deleteForEveryone(dto);

      const io = req.app.get('io');
      if (io) {
        io.to(data.conversationId).emit('message_deleted_for_everyone', {
          message_id: dto.message_id,
          conversation_id: data.conversationId,
        });
      }

      return res.json({ success: true, message: 'Message deleted for everyone', data });
    } catch (error: any) {
      const status = error.message.includes('expired') ? 400 : error.message.includes('own') ? 403 : 500;
      return res.status(status).json({ success: false, error: error.message });
    }
  }

  async deleteForMe(req: Request, res: Response) {
    try {
      const dto: DeleteForMeDto = req.body;
      const data = await communityService.deleteForMe(dto);
      return res.json({ success: true, message: 'Message deleted from your view', data });
    } catch (error: any) {
      return res.status(500).json({ success: false, error: error.message });
    }
  }
}
