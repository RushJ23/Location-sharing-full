#!/usr/bin/env bash
# build_prod_android.sh — Build a production Android App Bundle (AAB).
# Secrets are injected via --dart-define so they are compiled in and never bundled as a readable asset.
#
# Usage:
#   export SUPABASE_URL="https://your-project-ref.supabase.co"
#   export SUPABASE_ANON_KEY="your-supabase-anon-key-here"
#   export GOOGLE_MAPS_API_KEY="your-google-maps-api-key-here"
#   ./build_prod_android.sh

set -e

# ── Validate required environment variables ───────────────────────────────────

if [ -z "${SUPABASE_URL}" ]; then
  echo "ERROR: SUPABASE_URL is not set."
  echo "  export SUPABASE_URL=https://your-project-ref.supabase.co"
  exit 1
fi

if [ -z "${SUPABASE_ANON_KEY}" ]; then
  echo "ERROR: SUPABASE_ANON_KEY is not set."
  echo "  export SUPABASE_ANON_KEY=your-supabase-anon-key-here"
  exit 1
fi

if [ -z "${GOOGLE_MAPS_API_KEY}" ]; then
  echo "ERROR: GOOGLE_MAPS_API_KEY is not set."
  echo "  export GOOGLE_MAPS_API_KEY=your-google-maps-api-key-here"
  exit 1
fi

# ── Build ─────────────────────────────────────────────────────────────────────

echo "Building production Android App Bundle..."

flutter build appbundle --release \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}" \
  --dart-define="GOOGLE_MAPS_API_KEY=${GOOGLE_MAPS_API_KEY}"

echo ""
echo "Build succeeded."
echo "Output: build/app/outputs/bundle/release/app-release.aab"
