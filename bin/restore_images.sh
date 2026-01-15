#!/usr/bin/env bash
set -euo pipefail

# Restore (sync) only blog post images from the backup mirror into this repo.
# Source: /Users/sami/git/blog_image_backups
# Targets: content/posts/**/gallery/** and content/posts/**/feature.*

SRC="/Users/sami/git/blog_image_backups"
DEST="$(pwd)"

if [[ ! -d "$SRC/content/posts" ]]; then
  echo "ERROR: Source does not look right: $SRC/content/posts not found"
  exit 1
fi

echo "Restoring images from:"
echo "  SRC : $SRC"
echo "  DEST: $DEST"
echo

# Dry run if you pass --dry-run
DRYRUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
  DRYRUN="--dry-run"
  echo "Running in DRY RUN mode (no changes will be made)."
  echo
fi

# Notes:
# - We include directories so rsync can traverse to the included files.
# - We only include gallery and feature files.
# - Everything else is excluded.
# - We do NOT use --delete by default (safer). Add it if you want mirroring.
rsync -av $DRYRUN --prune-empty-dirs \
  --include='*/' \
  --include='content/posts/**/gallery/***' \
  --include='content/posts/**/feature.*' \
  --exclude='*' \
  "$SRC/" "$DEST/"

echo
echo "Done."
echo "Tip: run ./restore_images.sh --dry-run first to preview."

