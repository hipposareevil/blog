#!/bin/bash
rsync -av --prune-empty-dirs \
  --include='*/' \
  --include='content/posts/**/gallery/***' \
  --include='content/posts/**/feature.*' \
  --exclude='*' \
  ./   /Users/sami/blog_image_backups
