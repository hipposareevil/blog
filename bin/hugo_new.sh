#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/hugo_new_blog.sh "My Trip Title"
#   ./scripts/hugo_new_blog.sh "My Trip Title" my-custom-slug
#
# Creates:
#   content/posts/YYYY/slug/index.md
#   content/posts/YYYY/slug/gallery/

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTENT_DIR="$ROOT_DIR/content/posts"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 \"Post Title\" [slug]"
  exit 1
fi

TITLE="$1"
SLUG="${2:-}"

YEAR="$(date +%Y)"
NOW_ISO="$(date -Iseconds)"

# Basic slugify (lowercase, spaces->-, remove non-url chars)
slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[[:space:]]+/-/g; s/[^a-z0-9-]//g; s/-+/-/g; s/^-|-$//g'
}

if [[ -z "$SLUG" ]]; then
  SLUG="$(slugify "$TITLE")"
fi

DEST_DIR="$CONTENT_DIR/$YEAR/$SLUG"
INDEX_FILE="$DEST_DIR/index.md"
GALLERY_DIR="$DEST_DIR/gallery"

if [[ ! -d "$CONTENT_DIR/$YEAR" ]]; then
  echo "Year directory does not exist: $CONTENT_DIR/$YEAR"
  echo "Creating it..."
  mkdir -p "$CONTENT_DIR/$YEAR"
fi

if [[ -e "$INDEX_FILE" ]]; then
  echo "Already exists: $INDEX_FILE"
  exit 1
fi

mkdir -p "$GALLERY_DIR"

# If you want git to keep empty gallery dirs, uncomment:
# : > "$GALLERY_DIR/.gitkeep"

cat > "$INDEX_FILE" <<EOF
+++
title = "$TITLE"
date = "$NOW_ISO"
draft = true

# Optional defaults (edit/remove as you like)
# categories = []
# tags = []

featured = false
summary = ""
+++

{{< gallery id="gallery" >}}

EOF

echo "Created:"
echo "  $INDEX_FILE"
echo "  $GALLERY_DIR"
echo ""
echo "Next:"
echo "  - Put images in: $GALLERY_DIR/"
echo "  - Optionally add: $DEST_DIR/feature.jpg"
