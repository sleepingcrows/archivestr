#!/bin/bash
set -euo pipefail

REQUIRED=(
  NSECKEY
  BLOSSOMSRV
  )

if [[ -f .env ]]; then
  set -a 
  source .env
  set +a 
fi 

for var in "${REQUIRED[@]}"; do 
  : "${!var?: Missing required environment variable: $var}"
  [[ -n "${!var}" ]] || {
    echo "ERROR: $var is set but empty." >&2 
    exit 1
  }
done

#File Check
if [ ! -f $1 ]; then
  echo "File $1 does not exist. Exiting"
  exit 1
fi
SIDECAR="$1.txt"
#Sidecar Check
if [ ! -f $SIDECAR ]; then
  echo "Sidecar for $1 does not exist. Exiting"
  exit 1
fi

CREATOR=$(grep '^creator:' $SIDECAR | sed -E 's/.*creator:\s*([^\s]+).*/\1/')
echo $CREATOR

if [ -z $CREATOR ]; then
  echo "Sidecar was missing a creator. exiting"
  exit 1
fi

LINECOUNT=$(grep "^rating:" $SIDECAR | wc -l)
echo $LINECOUNT
if [[ $LINECOUNT -gt 1 ]]; then
  echo "More than one safety rating, exiting."
  exit 1 
else
  RATING=$(grep '^rating:' $SIDECAR | sed -E 's/.*rating:\s*([^ ]+).*/\1/')
  #RATING=$(grep "^rating:" $SIDECAR | sed -E 's/.*rating:\s*([^\s]+).*/\1/')
  echo $RATING
fi

# content format
# <URL>\n 
# Creator: $CREATOR\n
# $TAGS
# ====
# one-line '-c <URL>\nCreator: $CREATOR\n$TAGS'

#UPLOAD=$(nak blossom --server $BLOSSOMSRV --sec 01 upload $1 | jq .url)
#upload to mirrors just in case.
#nak blossom --server "blossom.yakihonne.com" --sec 01 upload $1
#nak blossom --server "blossom.sector01.com" --sec 01 upload $1 
#nak blossom --server "blossom.band" --sec 01 upload $1
#nak blossom --server "24242.io" --sec 01 upload $1
#CLEANLINK=$(echo "$UPLOAD" | sed 's/\"//g')
#MESSAGE="" #Artist name, year?
#pull tags from sidecar, if exists. matches filename.
#TAGS="" #Hashtags.
#METATAGS="" # -t tag 1 -t tag 2...
#CW='-t "content-warning"="NSFW"'
#NOTE="${CLEANLINK} ${MESSAGE} ${TAGS}"

#nak event -c "$NOTE" -t url=$CLEANLINK -t "content-warning"="Explicit" $METATAGS -k 1 --pow 28 --sec $NSECKEY | nak event wss://relay.nostr.band

#testing version
#nak event -c "$NOTE" -t url=$CLEANLINK $CW $METATAGS -k 1 --pow 28 --sec $NSECKEY

