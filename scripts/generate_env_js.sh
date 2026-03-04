#!/usr/bin/env bash
# Generate web/env.js from environment variables or a .env file.
# Usage:
#   ./scripts/generate_env_js.sh    # reads from environment or .env
#   FIREBASE_API_KEY=abc ./scripts/generate_env_js.sh

set -eu
OUT_FILE="web/env.js"

# If a .env file exists, load it (simple KEY=VALUE parser)
if [ -f .env ]; then
  echo "Loading .env"
  set -o allexport
  # shellcheck disable=SC1091
  source .env
  set +o allexport
fi

cat > "$OUT_FILE" <<EOF
window._env_ = {
  FIREBASE_API_KEY: "${FIREBASE_API_KEY:-}",
  FIREBASE_AUTH_DOMAIN: "${FIREBASE_AUTH_DOMAIN:-}",
  FIREBASE_PROJECT_ID: "${FIREBASE_PROJECT_ID:-}",
  FIREBASE_STORAGE_BUCKET: "${FIREBASE_STORAGE_BUCKET:-}",
  FIREBASE_MESSAGING_SENDER_ID: "${FIREBASE_MESSAGING_SENDER_ID:-}",
  FIREBASE_APP_ID: "${FIREBASE_APP_ID:-}",
};
EOF

echo "Wrote $OUT_FILE"
