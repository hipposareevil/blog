#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


rsync -azvv \
      -e 'ssh -p 66' \
       --exclude-from=${SCRIPT_DIR}/rsync-exclude.txt \
      public/  web\@willprogramforfood.com:/var/web_root/blog/
