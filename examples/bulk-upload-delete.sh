#!/bin/bash
#An example of a bulk uploading with ArchiveStr.sh w/ automatic deletion.

UPLOADDIR=""

find "$UPLOADDIR" -maxdepth 1 -type f ! -exec grep -Iq . {} \; -print0 | xargs -0 -n1 -P1 bash -c './archivestr.sh "$0" && rm -v -- "$0" "${0}.txt"'
