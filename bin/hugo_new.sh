#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/hugo_new.sh blog "Post Title" [slug]
#   ./scripts/hugo_new.sh pano "Panorama Title" [slug]

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

mkdir -p "$GALLERY_DIR"

if [[ -e "$INDEX_FILE" ]]; then
  echo "Already exists: $INDEX_FILE"
  exit 1
fi

cat > "$INDEX_FILE" <<EOF
+++
title = "$TITLE"
date = "$NOW_ISO"
draft = true$EXTRA_FRONTMATTER

featured = false
summary = ""
+++

$SHORTCODE

EOF

echo "Created:"
echo "  $INDEX_FILE"
echo "  $GALLERY_DIR"
echo "Tip: add feature image at: $DEST_DIR/feature.jpg"

# Open in Emacs
emacs "$INDEX_FILE" >/dev/null 2>&1 &
