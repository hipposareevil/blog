#!/bin/sh

rsync -azvv -e 'ssh -p 66' public/ web\@willprogramforfood.com:/var/web_root/blog/
