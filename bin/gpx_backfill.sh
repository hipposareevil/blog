#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./bin/gpx_backfill.sh content/posts/2026/mt-takorika-hike
#
# Reads:
#   staging/gpx/     — one or more .gpx workout files (merged by timestamp)
#   <post>/gallery/  — existing JPGs with embedded GPS EXIF
#
# Writes:
#   <post>/track.gpx     — merged GPX track
#   <post>/photos.json   — geotagged photo positions
#
# Does NOT modify index.md — add {{< gpxmap >}} manually if not already there.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GPX_PREPARE="$(dirname "${BASH_SOURCE[0]}")/gpx_prepare.py"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <post-directory>"
  echo "  e.g. $0 content/posts/2026/mt-takorika-hike"
  exit 1
fi

POST_DIR="$ROOT_DIR/$1"

# Allow absolute path too
if [[ "$1" == /* ]]; then
  POST_DIR="$1"
fi

if [[ ! -d "$POST_DIR" ]]; then
  echo "ERROR: Post directory not found: $POST_DIR"
  exit 1
fi

GALLERY_DIR="$POST_DIR/gallery"
GPX_DIR="$ROOT_DIR/staging/gpx"
TRACK_OUT="$POST_DIR/track.gpx"
PHOTOS_OUT="$POST_DIR/photos.json"

echo ""
echo "── Backfill: $(basename "$POST_DIR") ──────────────────────"

# ── GPX ──────────────────────────────────────────────────────────────────────

echo ""
echo "── GPX ──────────────────────────────────────"

if [[ ! -d "$GPX_DIR" ]] || ! compgen -G "$GPX_DIR/*.gpx" >/dev/null 2>&1; then
  echo "  No GPX files found in staging/gpx/ — skipping track.gpx"
else
  mapfile -t gpx_files < <(find "$GPX_DIR" -maxdepth 1 -iname "*.gpx" | sort)
  echo "  Found ${#gpx_files[@]} GPX file(s)"

  if [[ ${#gpx_files[@]} -eq 1 ]]; then
    echo "  Single file — copying directly."
    cp "${gpx_files[0]}" "$TRACK_OUT"
  else
    echo "  Multiple files — merging by timestamp…"
    python3 "$GPX_PREPARE" merge "$TRACK_OUT" "${gpx_files[@]}"
  fi

  echo "  Track written: $TRACK_OUT"

  # Clear staging gpx
  rm -f "${gpx_files[@]}"
  rmdir "$GPX_DIR" 2>/dev/null || true
  mkdir -p "$GPX_DIR"
  echo "  Staging/gpx cleared."
fi

# ── Photo GPS ─────────────────────────────────────────────────────────────────

echo ""
echo "── Photo GPS ────────────────────────────────"

if [[ ! -d "$GALLERY_DIR" ]]; then
  echo "  No gallery/ directory found — skipping photos.json"
else
  if ! command -v exiftool >/dev/null 2>&1; then
    echo "  WARN: exiftool not found — skipping photos.json"
  else
    python3 "$GPX_PREPARE" photos "$GALLERY_DIR" "$PHOTOS_OUT"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "── Done ─────────────────────────────────────"

[[ -f "$TRACK_OUT" ]]  && echo "  track.gpx    : $TRACK_OUT"
[[ -f "$PHOTOS_OUT" ]] && {
  COUNT=$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))))" "$PHOTOS_OUT" 2>/dev/null || echo "?")
  echo "  photos.json  : $COUNT geotagged photos"
}

echo ""
echo "  If {{< gpxmap >}} is not already in index.md, add it manually."
echo ""
