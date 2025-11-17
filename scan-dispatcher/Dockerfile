FROM node:20-alpine

RUN apk add --no-cache bash ca-certificates jq

WORKDIR /usr/src/app

COPY package.json package-lock.json* ./
RUN npm ci --production

COPY src ./src

# non-root user
RUN addgroup -S app && adduser -S -G app app
USER app

EXPOSE 3000
ENV NODE_ENV=production
CMD ["node", "src/index.js"]
