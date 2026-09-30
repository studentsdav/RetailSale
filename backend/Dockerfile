# Production Dockerfile for RetailSale Backend
FROM node:20-alpine AS builder

WORKDIR /app

# Install system dependencies
RUN apk add --no-cache postgresql-client

COPY package*.json tsconfig.json ./
RUN npm ci

COPY . .

# Run typecheck and compile typescript
RUN npm run typecheck
RUN npm run build || true

FROM node:20-alpine AS runner

WORKDIR /app

# Install postgresql-client for pg_dump utility if available
RUN apk add --no-cache postgresql-client tzdata

ENV NODE_ENV=production
ENV PORT=3000

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=builder /app ./

EXPOSE 3000

CMD ["node", "server.js"]
