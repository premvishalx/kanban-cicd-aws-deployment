
# Stage 1: Build the React application
FROM node:22-alpine AS build

WORKDIR /app

# Copy dependency files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy application source code
COPY . .

# Generate production build
RUN npm run build


# Stage 2: Serve the application using Nginx
FROM nginxinc/nginx-unprivileged:alpine

# Copy production files from the build stage
COPY --from=build /app/dist /usr/share/nginx/html

# Run Nginx as a non-root user
USER 101

# Expose the application port
EXPOSE 8080

# Container health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1

# Start Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
