const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');
require('dotenv').config();

const communityRoutes = require('./routes/communityRoutes');

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
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'RetailSale Community API is running' });
});

// Real-time WebSocket connection handling
io.on('connection', (socket) => {
  console.log(`Merchant connected to live socket: ${socket.id}`);

  // Join a channel or private room
  socket.on('join_room', (room) => {
    socket.join(room);
    console.log(`Socket ${socket.id} joined channel/room: ${room}`);
  });

  // Leave room
  socket.on('leave_room', (room) => {
    socket.leave(room);
    console.log(`Socket ${socket.id} left room: ${room}`);
  });

  // Broadcast typing indicator
  socket.on('typing', ({ conversationId, merchantName, isTyping }) => {
    socket.to(conversationId).emit('user_typing', { merchantName, isTyping });
  });

  socket.on('disconnect', () => {
    console.log(`Socket disconnected: ${socket.id}`);
  });
});

const PORT = process.env.PORT || 4000;
server.listen(PORT, () => {
  console.log(`🚀 RetailSale Community Chat Server (JS) listening on port ${PORT}`);
});
