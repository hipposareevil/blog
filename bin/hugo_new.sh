#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/hugo_new.sh blog "Post Title" [slug]
#   ./scripts/hugo_new.sh pano "Panorama Title" [slug]

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVOKE_DIR="$(pwd)"

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

# --- Image Conversion Subroutine ---

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

    echo "Converting HEIC -> JPG: $filename"
    if convert_to_jpg "$src" "$dest"; then
      rm -f "$src"
    else
      echo "WARN: Conversion failed, copying original HEIC."
      cp -v "$src" "$dest_dir/"
      rm -f "$src"
    fi
  else
    mv -v "$src" "$dest_dir/"
  fi
}

if [[ -z "$SLUG" ]]; then
  SLUG="$(slugify "$TITLE")"
fi

case "$TYPE" in
  blog)
    CONTENT_DIR="$ROOT_DIR/content/posts"
    SHORTCODE='{{< gallery id="gallery" >}}'
    EXTRA_FRONTMATTER=""
    ;;
  pano|panoramic)
    CONTENT_DIR="$ROOT_DIR/content/panoramic"
    SHORTCODE='{{< pano-gallery id="gallery" >}}'
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

PICS_DIR="$INVOKE_DIR/pics"

move_gallery_images() {
  local pics="$1"

  [[ -d "$pics" ]] || return 0

  mapfile -t imgs < <(find "$pics" -maxdepth 1 -type f \( \
      -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.heic' \
    \) -print | sort)

  if [[ ${#imgs[@]} -eq 0 ]]; then
    echo "No images found in: $pics"
    return 0
  fi

  echo "Processing ${#imgs[@]} image(s) from $pics -> $GALLERY_DIR"

  for f in "${imgs[@]}"; do
    copy_image "$f" "$GALLERY_DIR"
  done

  # Set first image as feature
  local first
  first="$(ls -1 "$GALLERY_DIR" 2>/dev/null | sort | head -n 1 || true)"
  [[ -n "$first" ]] && cp -v "$GALLERY_DIR/$first" "$FEATURE_PATH"
}

mkdir -p "$GALLERY_DIR"

if [[ -e "$INDEX_FILE" ]]; then
  echo "Already exists: $INDEX_FILE"
  exit 1
fi

cat > "$INDEX_FILE" <<EOF
+++
title = "$TITLE"
date = "$NOW_ISO"
draft = false
tags = []
categories = []

featured = false
summary = ""
+++

$SHORTCODE

EOF

echo "Created:"
echo "  $INDEX_FILE"
echo "  $GALLERY_DIR"

move_gallery_images "$PICS_DIR"

if [[ -s "$FEATURE_PATH" ]]; then
  echo "Feature image: $FEATURE_PATH"
else
  echo "Tip: add feature image at: $FEATURE_PATH"
fi

emacs "$INDEX_FILE" >/dev/null 2>&1 &
