# Use official Node.js 20 Alpine lightweight base image
FROM node:20-alpine

# Set working directory inside container
WORKDIR /app

# Install postgresql-client for pg_dump support
RUN apk add --no-cache postgresql-client

# Copy package definition files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production || npm install --omit=dev

# Copy application source code
COPY . .

# Expose default application port
EXPOSE 3000

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Start application
CMD ["node", "server.js"]
