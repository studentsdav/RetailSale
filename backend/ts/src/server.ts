import express, { Request, Response } from 'express';
import http from 'http';
import cors from 'cors';
import { Server } from 'socket.io';
import dotenv from 'dotenv';
import communityRoutes from './community/community.routes';

dotenv.config();

const app = express();
const server = http.createServer(app);

// Socket.IO for real-time community chat broadcasting
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

app.set('io', io);

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Mount routes
app.use('/api/community', communityRoutes);

// Health check route
app.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'OK', message: 'RetailSale Community API (TS) is running' });
});

// Real-time WebSocket connection handling
io.on('connection', (socket) => {
  console.log(`[TS-Server] Merchant connected to live socket: ${socket.id}`);

  socket.on('join_room', (room: string) => {
    socket.join(room);
    console.log(`[TS-Server] Socket ${socket.id} joined room: ${room}`);
  });

  socket.on('leave_room', (room: string) => {
    socket.leave(room);
    console.log(`[TS-Server] Socket ${socket.id} left room: ${room}`);
  });

  socket.on('typing', ({ conversationId, merchantName, isTyping }: { conversationId: string; merchantName: string; isTyping: boolean }) => {
    socket.to(conversationId).emit('user_typing', { merchantName, isTyping });
  });

  socket.on('disconnect', () => {
    console.log(`[TS-Server] Socket disconnected: ${socket.id}`);
  });
});

const PORT = process.env.PORT || 4000;
server.listen(PORT, () => {
  console.log(`🚀 RetailSale Community Chat Server (TypeScript) listening on port ${PORT}`);
});
