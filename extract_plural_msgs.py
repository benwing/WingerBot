#!/bin/bash

grep 'Page ' "$@" | perl5.16 -pe 's/Page (.*?):/Page :/;' \
    -e 's/[^\x00-\x7F]+ \(.*?\)//g;' \
    -e 's/[^\x00-\x7F]//g;' \
    -e 's/\(tr=.*\)//g;' \
    | sort | uniq -c | sort -nr
