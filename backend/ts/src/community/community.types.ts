export interface ChatAttachmentPayload {
  type: 'PRODUCT' | 'PURCHASE_ORDER' | 'IMAGE';
  id: string;
  title: string;
  subtitle?: string;
  price?: number;
  imageUrl?: string;
  metadata?: Record<string, any>;
}

export interface SendMessageDto {
  id?: string;
  conversation_id: string;
  sender_id: string;
  sender_name: string;
  sender_trade_name?: string;
  sender_city?: string;
  sender_gstin?: string;
  sender_phone?: string;
  content: string;
  attachment?: ChatAttachmentPayload;
}

export interface DeleteForEveryoneDto {
  message_id: string;
  sender_id: string;
}

export interface DeleteForMeDto {
  message_id: string;
  user_id: string;
}
