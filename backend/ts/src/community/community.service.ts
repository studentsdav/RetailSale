import { PrismaClient } from '@prisma/client';
import { SendMessageDto, DeleteForEveryoneDto, DeleteForMeDto } from './community.types';

export class CommunityService {
  private prisma: PrismaClient;

  constructor(prisma?: PrismaClient) {
    this.prisma = prisma || new PrismaClient();
  }

  async getConversations(city: string = 'Dehradun', merchantId?: string) {
    const regional = await this.prisma.communityConversation.findMany({
      where: {
        OR: [
          {
            isDirect: false,
            regionCity: { equals: city, mode: 'insensitive' },
          },
          ...(merchantId
            ? [
                {
                  isDirect: true,
                  OR: [
                    { id: { contains: merchantId } },
                    { directRecipientId: merchantId },
                  ],
                },
              ]
            : []),
        ],
      },
      include: {
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
      },
      orderBy: { updatedAt: 'desc' },
    });

    return regional.map((conv) => ({
      ...conv,
      last_message: conv.messages[0] || null,
    }));
  }

  async getMessages(conversationId: string, merchantId?: string) {
    return this.prisma.communityMessage.findMany({
      where: {
        conversationId,
        ...(merchantId
          ? {
              deletedUsers: {
                none: { userId: merchantId },
              },
            }
          : {}),
      },
      include: {
        deletedUsers: {
          select: { userId: true },
        },
        mentions: {
          select: { mentionedHandle: true },
        },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  async sendMessage(dto: SendMessageDto) {
    const msgId = dto.id || `msg_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

    // Parse @mentions
    const mentionRegex = /@([a-zA-Z0-9_-]+)/g;
    let match;
    const mentionedHandles: string[] = [];
    if (dto.content) {
      while ((match = mentionRegex.exec(dto.content)) !== null) {
        mentionedHandles.push(match[1]);
      }
    }

    const message = await this.prisma.communityMessage.create({
      data: {
        id: msgId,
        conversationId: dto.conversation_id,
        senderId: dto.sender_id,
        senderName: dto.sender_name,
        senderTradeName: dto.sender_trade_name || '',
        senderCity: dto.sender_city || '',
        senderGstin: dto.sender_gstin || '',
        senderPhone: dto.sender_phone || '',
        content: dto.content,
        attachment: dto.attachment ? JSON.stringify(dto.attachment) : undefined,
        mentions: {
          create: mentionedHandles.map((handle) => ({ mentionedHandle: handle })),
        },
      },
      include: {
        mentions: true,
      },
    });

    await this.prisma.communityConversation.update({
      where: { id: dto.conversation_id },
      data: { updatedAt: new Date() },
    });

    return message;
  }

  async deleteForEveryone(dto: DeleteForEveryoneDto) {
    const msg = await this.prisma.communityMessage.findUnique({
      where: { id: dto.message_id },
    });

    if (!msg) throw new Error('Message not found');
    if (msg.senderId !== dto.sender_id) {
      throw new Error('You can only delete your own message for everyone');
    }

    const diffHours = (Date.now() - msg.createdAt.getTime()) / (1000 * 60 * 60);
    if (diffHours >= 2) {
      throw new Error('Delete for everyone has expired (restricted to 2 hours)');
    }

    return this.prisma.communityMessage.update({
      where: { id: dto.message_id },
      data: {
        isDeletedForEveryone: true,
        content: '🚫 This message was deleted',
        attachment: undefined,
      },
    });
  }

  async deleteForMe(dto: DeleteForMeDto) {
    return this.prisma.communityMessageDeletedUser.upsert({
      where: {
        messageId_userId: {
          messageId: dto.message_id,
          userId: dto.user_id,
        },
      },
      create: {
        messageId: dto.message_id,
        userId: dto.user_id,
      },
      update: {},
    });
  }
}
