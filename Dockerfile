# =======================================================
# Production Dockerfile for Shop POS & Admin Web Monolith
# Serves:
#  - REST API (/api/*)
#  - Admin Web Dashboard (/)
#  - Staff POS Web App (/pos)
#  - Product Uploads (/uploads)
# =======================================================

FROM node:20-alpine AS runner

WORKDIR /app

# Install curl for container healthcheck and tzdata for accurate IST timestamps
RUN apk add --no-cache curl tzdata

# Set default timezone to Asia/Kolkata (Indian Standard Time)
ENV TZ=Asia/Kolkata

# 1. Copy backend package definition files
COPY backend/package*.json ./backend/

# 2. Install production dependencies
WORKDIR /app/backend
RUN npm ci --omit=dev || npm install --omit=dev

# 3. Copy backend source code
COPY backend/ ./

# 4. Copy admin web dashboard
WORKDIR /app
COPY admin_web/ ./admin_web/

# 5. Copy prebuilt staff mobile Flutter web application
COPY staff_mobile/build/web/ ./staff_mobile/build/web/

# 6. Ensure persistent uploads folder exists
RUN mkdir -p /app/admin_web/uploads

# 7. Switch back to backend workdir to run server.js
WORKDIR /app/backend

ENV NODE_ENV=production
ENV PORT=5000

EXPOSE 5000

# Healthcheck to verify the Express server is up
HEALTHCHECK --interval=20s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:5000/ || exit 1

CMD ["node", "server.js"]
