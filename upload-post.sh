#!/bin/bash
set -euo pipefail
: ${1?"Usage: $0 <path to file>
(every file needs a .txt sidecar with a rating and creator namespace at minimum!)"}
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

COMMANDS=("sed" "grep" "nak")
missing_apps=()
for app in "${COMMANDS[@]}"; do 
  if ! command -v "$app" &> /dev/null; then 
    missing_apps+=("$app")
  fi 
done 

if [[ ${#missing_apps[@]} -gt 0 ]]; then
  echo "error: missing commands" 
  for app in "${missing_apps[@]}"; do 
     echo $app 
   done
   echo "make sure you have them installed, or that your PATH is set. exiting."
   exit 1
fi

if [ -z {$1} ]; then
  exit 1
fi

if [ ! -f $1 ]; then
  echo "File $1 does not exist."
  echo "Exiting."
  exit 1
fi
SIDECAR="$1.txt"

if [ ! -f $SIDECAR ]; then
  echo "Sidecar for $1 does not exist."
  echo "Exiting."
  exit 1
fi


CREATORS=() #can be multiple.
RATINGS=() #should only ever have one content rating.
SPECIES=() #furry centric namespace.
CHARACTERS=()
SERIES=() #copyright holders, content titles
TAGS=() #general tags.


echo "===processing tags.==="
while IFS= read -r line; do 
  case $line in 
    creator:*)
      CREATORS+=("${line:8}")
      ;;
    rating:*)
      RATINGS+=("${line:7}")
      ;;
    species:*)
      SPECIES+=("${line:8}")
      ;;
    character:*)
      CHARACTERS+=("${line:10}")
      ;;
    series:*)
      SERIES+=("${line:7}")
      ;;
    *)
      TAGS+=("$line")
      ;;
  esac 

done < $SIDECAR

#Tag Validations
set +u
if [ ${#CREATORS[@]} -eq 0 ]; then
  echo "creator missing. exiting"
  exit 1
fi

if [ ${#RATINGS[@]} -ne 1 ]; then
  echo "too many or too few ratings. exiting"
  exit 1
fi
set -u

echo "Creators: ${CREATORS[@]}"
echo "Ratings: ${RATINGS[@]}"
echo "Species: ${SPECIES[@]}"
echo "Series: ${SERIES[@]}"
echo "Characters: ${CHARACTERS[@]}"
echo "Tags: ${TAGS[@]}"

echo "done"
# Why Did i think this was a good idea...

#CREATOR=$(grep '^creator:' $SIDECAR | sed -E 's/.*creator:\s*([^\s]+).*/\1/')
#echo creator: $CREATOR
#if [ -z $CREATOR ]; then
#  echo "Sidecar was missing a creator. exiting"
#  exit 1
#fi

#LINECOUNT=$(grep "^rating:" $SIDECAR | wc -l)
#echo $LINECOUNT
#if [[ $LINECOUNT -gt 1 ]]; then
#  echo "More than one safety rating, exiting."
#  exit 1 
#else
#  RATING=$(grep '^rating:' $SIDECAR | sed -E 's/.*rating:\s*([^ ]+).*/\1/')
#  echo $RATING
#fi

#METATAGS=()
#METATAGS+=('-t "namespace"="example"')

#if [[ "$RATING" != "safe" ]]; then
#  METATAGS+=("-t 'content-warning'='NSFW'")
#  METATAGS+=("-t 'rating'='$RATING'")
#else
#  METATAGS+=("-t 'rating'='$RATING'")
#fi

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

