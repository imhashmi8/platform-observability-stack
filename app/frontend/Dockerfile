# syntax=docker/dockerfile:1
# Stage 1: build the static SPA.
FROM node:20-alpine AS builder

WORKDIR /app
COPY package.json package-lock.json* ./
# Use a clean, reproducible install. Falls back to `npm install` when no lockfile
# is present (first build before a lockfile is committed).
RUN npm ci 2>/dev/null || npm install
COPY . .
RUN npm run build


# Stage 2: serve with nginx (unprivileged, listens on 8080).
FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime

# nginx's entrypoint renders *.template with envsubst at startup. The filter
# ensures ONLY ${BACKEND_URL} is substituted, leaving nginx's own $host/$remote_addr
# variables intact.
ENV NGINX_ENVSUBST_FILTER="BACKEND_URL" \
    BACKEND_URL="http://backend.sample-app.svc.cluster.local:8000"

COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 8080
