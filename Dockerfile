# Use official Node.js 20 Alpine lightweight base image
FROM node:20-alpine

# Set working directory inside container
WORKDIR /app

# Copy package definition files from backend directory
COPY backend/package*.json ./

# Install production dependencies
RUN npm ci --only=production || npm install --omit=dev

# Copy backend source code into container
COPY backend/ .

# Expose backend port
EXPOSE 3000

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Start application
CMD ["node", "server.js"]
