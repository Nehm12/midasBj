#!/bin/sh
set -e

echo "⏳ Running Prisma migrations..."
npx prisma migrate deploy --schema=./prisma/schema.prisma 2>/dev/null || npx prisma db push --schema=./prisma/schema.prisma --accept-data-loss

echo "🌱 Seeding database..."
npx tsx src/seed.ts 2>/dev/null || echo "⚠️ Seed skipped (data may already exist)"

echo "🚀 Starting MIDAS-Bénin backend..."
exec node dist/index.js
