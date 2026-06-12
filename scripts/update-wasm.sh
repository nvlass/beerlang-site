#!/usr/bin/env bash
# Rebuild the beerlang WASM bundle and copy it into the site.
# Run from the beerlang-site root: ./scripts/update-wasm.sh
set -e
SITE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LANG_DIR="$(cd "$SITE_DIR/../beerlang" && pwd)"

echo "==> Building WASM (via Docker)..."
make -C "$LANG_DIR" wasm-docker

echo "==> Copying artifacts..."
cp "$LANG_DIR/wasm/out/beerlang.js"   "$SITE_DIR/themes/lotus/wasm/"
cp "$LANG_DIR/wasm/out/beerlang.wasm" "$SITE_DIR/themes/lotus/wasm/"
cp "$LANG_DIR/wasm/out/beerlang.js"   "$SITE_DIR/public/wasm/"
cp "$LANG_DIR/wasm/out/beerlang.wasm" "$SITE_DIR/public/wasm/"

echo "==> Done. Run 'clojure -M:build' to regenerate the full site."
