# Dockerfile for Open Embed Router
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json package-lock.json* ./

# Install production dependencies only
RUN npm ci --omit=dev || npm install --production

# Copy source files
COPY src/ ./src/

# Create logs directory
RUN mkdir -p /app/logs

# Set environment variables
ENV PORT=9000
ENV NODE_ENV=production

# Configuration environment variables
# PROVIDER - Provider type: "openai" or "ollama"
# PROVIDER_BASE_URL - The base URL for the provider API
# API_KEY - API key for authentication (optional for Ollama)
LABEL org.opencontainers.image.description="Open Embed Router - Provider-agnostic embeddings API router"

# Expose port
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:9000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Start application
CMD ["node", "src/index.js"]
