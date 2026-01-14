#!/usr/bin/env bash
set -euo pipefail

# Hugo cleanup script that preserves cached processed IMAGES.
# Safe default:
#   - removes public/ (output)
#   - removes .hugo_build.lock
#   - removes server/build leftovers
# Optional:
#   --assets  : also clears generated CSS/JS pipeline output in resources/_gen/assets
#   --all     : nukes all resources/_gen (SLOW: reprocesses images)  [not recommended]

ROOT="$(pwd)"

PUBLIC="$ROOT/public"
LOCK="$ROOT/.hugo_build.lock"
RESGEN="$ROOT/resources/_gen"

usage() {
  cat <<EOF
Usage: ./hugo_clean.sh [--assets] [--all]

  (no flags)  Remove public/ and hugo lock files. Keeps all caches.
  --assets    Also remove generated CSS/JS cache (resources/_gen/assets).
              Keeps processed images cache.
  --all       Remove ALL resources/_gen (slow, reprocesses images). Avoid unless necessary.
EOF
}

MODE="safe"
if [[ "${1:-}" == "--assets" ]]; then
  MODE="assets"
elif [[ "${1:-}" == "--all" ]]; then
  MODE="all"
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
elif [[ "${1:-}" != "" ]]; then
  echo "Unknown option: ${1}"
  usage
  exit 1
fi

echo "Hugo clean mode: $MODE"
echo "Repo: $ROOT"
echo

# 1) Always safe: remove rendered output and lock
if [[ -d "$PUBLIC" ]]; then
  echo "Removing: $PUBLIC"
  /bin/rm -rf "$PUBLIC"
fi

if [[ -f "$LOCK" ]]; then
  echo "Removing: $LOCK"
  /bin/rm -f "$LOCK"
fi

# 2) Optionally clear generated assets, but keep image cache
if [[ "$MODE" == "assets" ]]; then
  if [[ -d "$RESGEN/assets" ]]; then
    echo "Removing generated assets cache: $RESGEN/assets"
    /bin/rm -rf "$RESGEN/assets"
  fi
  # Some Hugo versions may also use js/css under resources/_gen (non-images)
  if [[ -d "$RESGEN/files" ]]; then
    echo "Removing generated files cache: $RESGEN/files"
    /bin/rm -rf "$RESGEN/files"
  fi
fi

# 3) Nuclear option (not recommended): remove all resource cache including images
if [[ "$MODE" == "all" ]]; then
  if [[ -d "$RESGEN" ]]; then
    echo "Removing ALL resources cache: $RESGEN"
    /bin/rm -rf "$RESGEN"
  fi
fi

echo
echo "Done."
echo "Tip: rebuild with:"
echo "  hugo server --disableFastRender"

