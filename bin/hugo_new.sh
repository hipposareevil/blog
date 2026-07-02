#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/hugo_new.sh blog "Post Title" [slug]
#   ./scripts/hugo_new.sh pano "Panorama Title" [slug]
#
# Drop files into staging/ before running (from anywhere):
#   staging/pics/   — HEIC / JPG images (converted + moved to gallery/)
#   staging/gpx/    — one or more .gpx files (merged into track.gpx, combined by time)
#
# Staging is cleared automatically after a successful run.
#
# Outputs inside the new post bundle:
#   gallery/        — converted JPG images
#   track.gpx       — merged GPX track (if gpx/ had any files)
#   photos.json     — geotagged photo positions (requires exiftool)
#   index.md        — front matter + shortcodes

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Path to gpx_prepare.py — expected alongside this script in bin/
GPX_PREPARE="$(dirname "${BASH_SOURCE[0]}")/gpx_prepare.py"

if [[ $# -lt 2 ]]; then
  echo "Usage:"
  echo "  $0 blog \"Post Title\" [slug]"
  echo "  $0 pano \"Panorama Title\" [slug]"
  exit 1
fi

TYPE="$1"
TITLE="$2"
SLUG="${3:-}"

YEAR="$(date +%Y)"
NOW_ISO="$(date -Iseconds)"

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[[:space:]]+/-/g; s/[^a-z0-9-]//g; s/-+/-/g; s/^-|-$//g'
}

# ── Image conversion ──────────────────────────────────────────────────────────

convert_to_jpg() {
  local src="$1"
  local dest="$2"

  if command -v heif-convert >/dev/null 2>&1; then
    heif-convert "$src" "$dest" >/dev/null 2>&1 && return 0
  elif command -v magick >/dev/null 2>&1; then
    magick "$src" "$dest" >/dev/null 2>&1 && return 0
  elif command -v convert >/dev/null 2>&1; then
    convert "$src" "$dest" >/dev/null 2>&1 && return 0
  elif command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -i "$src" "$dest" >/dev/null 2>&1 && return 0
  fi

  return 1
}

copy_image() {
  local src="$1"
  local dest_dir="$2"

  local filename
  filename="$(basename "$src")"
  local ext="${filename##*.}"
  ext="${ext,,}"

  if [[ "$ext" == "heic" ]]; then
    local newname="${filename%.*}.jpg"
    local dest="$dest_dir/$newname"

    echo "  Converting HEIC -> JPG: $filename"
    if convert_to_jpg "$src" "$dest"; then
      rm -f "$src"
    else
      echo "  WARN: Conversion failed, copying original HEIC."
      cp -v "$src" "$dest_dir/"
      rm -f "$src"
    fi
  else
    mv -v "$src" "$dest_dir/"
  fi
}

# ── GPX handling ──────────────────────────────────────────────────────────────

process_gpx() {
  local gpx_src_dir="$1"   # e.g. $INVOKE_DIR/gpx
  local dest_dir="$2"      # post bundle root

  [[ -d "$gpx_src_dir" ]] || return 0

  mapfile -t gpx_files < <(find "$gpx_src_dir" -maxdepth 1 -iname "*.gpx" | sort)

  if [[ ${#gpx_files[@]} -eq 0 ]]; then
    echo "  No GPX files found in: $gpx_src_dir"
    return 0
  fi

  local track_out="$dest_dir/track.gpx"

  echo ""
  echo "── GPX ──────────────────────────────────────"
  echo "  Found ${#gpx_files[@]} GPX file(s):"

  if [[ ${#gpx_files[@]} -eq 1 ]]; then
    echo "  Single file — copying directly."
    cp "${gpx_files[0]}" "$track_out"
  else
    echo "  Multiple files — merging by timestamp…"
    python3 "$GPX_PREPARE" merge "$track_out" "${gpx_files[@]}"
  fi

  echo "  Track written: $track_out"

  # Clean up source gpx dir
  rm -f "${gpx_files[@]}"
  rmdir "$gpx_src_dir" 2>/dev/null || true
}

# ── Photo GPS extraction ───────────────────────────────────────────────────────

extract_photo_gps() {
  local gallery_dir="$1"
  local dest_dir="$2"

  [[ -d "$gallery_dir" ]] || return 0

  if ! command -v exiftool >/dev/null 2>&1; then
    echo "  WARN: exiftool not found — skipping photos.json extraction."
    return 0
  fi

  local photos_out="$dest_dir/photos.json"
  echo ""
  echo "── Photo GPS ────────────────────────────────"
  python3 "$GPX_PREPARE" photos "$gallery_dir" "$photos_out"
}

# ── Image gallery ─────────────────────────────────────────────────────────────

move_gallery_images() {
  local pics="$1"

  [[ -d "$pics" ]] || return 0

  mapfile -t imgs < <(find "$pics" -maxdepth 1 -type f \( \
      -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.heic' \
    \) -print | sort)

  if [[ ${#imgs[@]} -eq 0 ]]; then
    echo "  No images found in: $pics"
    return 0
  fi

  echo ""
  echo "── Images ───────────────────────────────────"
  echo "  Processing ${#imgs[@]} image(s): $pics → $GALLERY_DIR"

  for f in "${imgs[@]}"; do
    copy_image "$f" "$GALLERY_DIR"
  done

  # Set first image as feature
  local first
  first="$(ls -1 "$GALLERY_DIR" 2>/dev/null | sort | head -n 1 || true)"
  [[ -n "$first" ]] && cp -v "$GALLERY_DIR/$first" "$FEATURE_PATH"
}

# ── Setup ─────────────────────────────────────────────────────────────────────

if [[ -z "$SLUG" ]]; then
  SLUG="$(slugify "$TITLE")"
fi

case "$TYPE" in
  blog)
    CONTENT_DIR="$ROOT_DIR/content/posts"
    SHORTCODE_GALLERY='{{< gallery id="gallery" >}}'
    SHORTCODE_MAP='{{< gpxmap >}}'
    EXTRA_FRONTMATTER=""
    ;;
  pano|panoramic)
    CONTENT_DIR="$ROOT_DIR/content/panoramic"
    SHORTCODE_GALLERY='{{< pano-gallery id="gallery" >}}'
    SHORTCODE_MAP=""
    EXTRA_FRONTMATTER=$'\ncategories = ["panoramic"]\ntags = ["panoramic"]'
    ;;
  *)
    echo "Unknown type: $TYPE"
    echo "Valid types: blog | pano"
    exit 1
    ;;
esac

DEST_DIR="$CONTENT_DIR/$YEAR/$SLUG"
INDEX_FILE="$DEST_DIR/index.md"
GALLERY_DIR="$DEST_DIR/gallery"
FEATURE_PATH="$DEST_DIR/feature.jpg"

PICS_DIR="$ROOT_DIR/staging/pics"
GPX_DIR="$ROOT_DIR/staging/gpx"

# Check for existing post
if [[ -e "$INDEX_FILE" ]]; then
  echo "Already exists: $INDEX_FILE"
  exit 1
fi

mkdir -p "$GALLERY_DIR"

# ── Detect GPX presence for front matter ────────────────────────────────────

HAS_GPX=false
if [[ -d "$GPX_DIR" ]] && compgen -G "$GPX_DIR/*.gpx" >/dev/null 2>&1; then
  HAS_GPX=true
fi

# ── Write front matter ────────────────────────────────────────────────────────

{
cat <<EOF
+++
title = "$TITLE"
date = "$NOW_ISO"
draft = false
tags = []
categories = []
featured = false
summary = ""
EOF

if [[ -n "$EXTRA_FRONTMATTER" ]]; then
  echo "$EXTRA_FRONTMATTER"
fi

if $HAS_GPX; then
  echo 'hasMap = true'
fi

echo '+++'
echo ""

if $HAS_GPX && [[ -n "$SHORTCODE_MAP" ]]; then
  echo "$SHORTCODE_MAP"
  echo ""
fi

echo "$SHORTCODE_GALLERY"
echo ""
} > "$INDEX_FILE"

echo "Created:"
echo "  $INDEX_FILE"
echo "  $GALLERY_DIR"

# ── Process in order: GPX → images → photo GPS ──────────────────────────────

process_gpx    "$GPX_DIR"   "$DEST_DIR"
move_gallery_images "$PICS_DIR"
extract_photo_gps "$GALLERY_DIR" "$DEST_DIR"

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "── Done ─────────────────────────────────────"

if [[ -s "$FEATURE_PATH" ]]; then
  echo "  Feature image : $FEATURE_PATH"
else
  echo "  Tip: add feature image at: $FEATURE_PATH"
fi

if [[ -f "$DEST_DIR/track.gpx" ]]; then
  echo "  GPX track     : $DEST_DIR/track.gpx"
fi

if [[ -f "$DEST_DIR/photos.json" ]]; then
  COUNT=$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))))" "$DEST_DIR/photos.json" 2>/dev/null || echo "?")
  echo "  Photo pins    : $COUNT geotagged photos in photos.json"
fi

echo ""

# ── Reset staging for next trip ───────────────────────────────────────────────

rm -rf "$PICS_DIR" "$GPX_DIR"
mkdir -p "$PICS_DIR" "$GPX_DIR"
echo "  Staging cleared: ready for next trip."
echo ""

emacs "$INDEX_FILE" >/dev/null 2>&1 &
