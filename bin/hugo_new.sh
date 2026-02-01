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

# If a ./pics directory exists where the script is invoked, we'll move images into the new gallery.
PICS_DIR="$INVOKE_DIR/pics"

move_gallery_images() {
  local pics="$1"

  [[ -d "$pics" ]] || return 0

  # Collect candidate images (case-insensitive): jpg/jpeg/heic
  mapfile -t imgs < <(find "$pics" -maxdepth 1 -type f \( \
      -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.heic' \
    \) -print | sort)

  if [[ ${#imgs[@]} -eq 0 ]]; then
    echo "No images found in: $pics (expected .jpg/.jpeg/.heic)"
    return 0
  fi

  echo "Moving ${#imgs[@]} image(s) from $pics -> $GALLERY_DIR"
  for f in "${imgs[@]}"; do
    mv -v "$f" "$GALLERY_DIR/"
  done

  # If ./pics is now empty, remove it (optional nicety).
  rmdir "$pics" 2>/dev/null || true

  # Pick the first image in the gallery (sorted by name) as the feature source.
  local first
  first="$(ls -1 "$GALLERY_DIR" 2>/dev/null | sort | head -n 1 || true)"
  if [[ -z "$first" ]]; then
    return 0
  fi

  local src="$GALLERY_DIR/$first"
  local ext="${first##*.}"
  ext="${ext,,}"

  if [[ "$ext" == "jpg" || "$ext" == "jpeg" ]]; then
    cp -v "$src" "$FEATURE_PATH"
    return 0
  fi

  if [[ "$ext" == "heic" ]]; then
    echo "First image is HEIC; attempting to convert -> $FEATURE_PATH"
    if command -v heif-convert >/dev/null 2>&1; then
      heif-convert "$src" "$FEATURE_PATH" >/dev/null || true
    elif command -v magick >/dev/null 2>&1; then
      magick "$src" "$FEATURE_PATH" || true
    elif command -v convert >/dev/null 2>&1; then
      convert "$src" "$FEATURE_PATH" || true
    elif command -v ffmpeg >/dev/null 2>&1; then
      ffmpeg -y -i "$src" "$FEATURE_PATH" >/dev/null 2>&1 || true
    else
      echo "WARN: No HEIC converter found (heif-convert/magick/convert/ffmpeg)."
      echo "      Copying as: $DEST_DIR/feature.heic"
      cp -v "$src" "$DEST_DIR/feature.heic"
    fi

    # If conversion failed for any reason, fall back to feature.heic.
    if [[ ! -s "$FEATURE_PATH" ]]; then
      echo "WARN: HEIC->JPG conversion did not produce $FEATURE_PATH"
      echo "      Copying as: $DEST_DIR/feature.heic"
      cp -v "$src" "$DEST_DIR/feature.heic"
    fi
  fi
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

# Open in Emacs
emacs "$INDEX_FILE" >/dev/null 2>&1 &
