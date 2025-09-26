#!/bin/bash
set -e

echo "🔍 External Services Status Check:"
echo "  PostgreSQL: $POSTGRES_STATUS ($POSTGRES_HEALTH)"
echo "  MinIO: $MINIO_STATUS ($MINIO_HEALTH)"
echo "  Overall: $SERVICES_READY"

if [ "$SERVICES_READY" = "not_running" ]; then
  echo ""
  echo "⚠️  External services are not running!"
  echo "💡 To start them, run: make services-setup"
  echo "💡 Or manually: cd infra/docker && docker-compose up -d"
  echo ""
  echo "💡 This approach ensures platform resilience and automated recovery"
elif [ "$SERVICES_READY" = "assumed_healthy" ]; then
  echo "⚠️  External services are running but health checks unavailable"
  echo "✅ Assuming services are healthy and proceeding..."
else
  echo "✅ External services are healthy and ready!"
fi
