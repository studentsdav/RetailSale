# Use official Node.js 20 Alpine lightweight base image
FROM node:20-alpine

# Set working directory inside container
WORKDIR /app

# Install postgresql-client for pg_dump support and tzdata for accurate timezone support
RUN apk add --no-cache postgresql-client tzdata

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
ENV TZ=Asia/Kolkata
ENV DEFAULT_TIMEZONE=Asia/Kolkata

# Start application
CMD ["node", "server.js"]
