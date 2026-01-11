#!/bin/bash
#ArchiveStr V2
#Note: Keeping comments verbose on this rebuild for now, need a mental map!
set -euo pipefail
#Need to convert Blossom Server lists to an array, make it fail gracefully.
#Help Line
: ${1?"Usage: $0 <path to file>
(every file needs a .txt sidecar with a rating and creator namespace at minimum!)"}

REQUIRED=(
  NSECKEY
  BLOSSOMSRV
  )

COMMANDS=(
  "sed"
  "grep"
  "nak"
  "awk"
  )

if [[ -f .env ]]; then
  set -a
  source .env 
  set +a 
fi

#Unique Temp File, avoiding mangle 
FILEID=note.$$.tmp

for var in "${REQUIRED[@]}"; do
  : "${!var?: Missing required environment variable: $var}"
  [[ -n "${!var}" ]] || {
    echo "ERROR: $var is set but empty." >&2
    exit 1
  }
done

# Command Dependencies
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

#check for arguments & valid paths.
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

CREATORS=() #one or more
RATINGS=() #should only ever be one.
declare -A taglist

append_to_taglist () {
  key="$1"
  value="$2"
  taglist[$key]+="$value,"
}

#pre-process logic: check if "creator" and "rating" exist, exit if one of them is missing. 
while IFS=':' read -r namespace tag; do 
  if [ -z "$tag" ]; then
    tag="$namespace"
    namespace="tag"
  fi

  if [ "$namespace" = "creator" ]; then
    echo "namespace was a creator"
    CREATORS+=($tag)
  elif [ "$namespace" = "rating" ]; then
    echo "namespace was a rating"
    RATINGS+=$tag
  fi

  echo "$tag"
  append_to_taglist "$namespace" "$tag"
  
done < $SIDECAR

creatorcount=0
ratingcount=0

echo "==="
for key in "${!taglist[@]}"; do 
  echo "$key:"
  IFS=',' read -r -a values <<< "${taglist[$key]}"
  for value in "${values[@]}"; do
    echo "  - $value"
    if [ "$key" = "creator" ]; then
      creatorcount=$((creatorcount+1))
    elif [ "$key" = "rating" ]; then
      ratingcount=$((ratingcount+1))
    fi
  done
done

echo "Rating Count: $ratingcount (target = 1) | Creator Count: $creatorcount (target > 0)"

# Minimum Tag Requirements
if [[ $ratingcount -ne 1 || $creatorcount -lt 1 ]]; then
  echo "sidecar fails to meet required namespaced tag counts. exiting."
  exit 1
else
  echo "sidecar meets minimum requirements!"
  set +u 
  if [[ ! " ${RATINGS[@]} " =~ " safe " ]]; then
    echo "Content is NSFW, adding CW."
    METADATA+="-t content-warning=nsfw "
  fi
  set -u
fi

# upload the file, store the returned URL 
# Temp method, does not mirror to multiple services.
# I need to make this fail gracefully, and retry anotherserver
# in case the filesize exceeds the server's size quota.

# Determine if the file has a previous post associated with the target npub
# To perform a content update, instead of a new post.

echo ===Uploading File to $BLOSSOMSRV===
UPLOADURL=$(nak blossom --server $BLOSSOMSRV --sec $NSECKEY upload $1 | jq .url | sed 's/\"//g')
echo $UPLOADURL

touch $FILEID
HASHTAGSTR=""
echo $UPLOADURL > $FILEID
echo ===

for key in "${!taglist[@]}"; do 
  IFS=',' read -r -a values <<< "${taglist[$key]}"
  for value in "${values[@]}"; do
    HASHTAGSTR+=$(echo "#$value" | sed 's/ /_/g; s/[:"!.-]//g; s/[()]//g; s/[][]//g' | awk {'print $0 " "'} )
    METADATA+=$(echo "$key=$value" | sed 's/ /_/g; s/["]//g;' | awk {'print "-t " $0 " "'} )
  done
done

counter=0
CREATORLINE=""
set +u
if [ ${#CREATORS[@]} -gt 1 ]; then
  CREATORLINE+="Creators: "
  for creator in "${CREATORS[@]}"; do
    if (( counter == 0 )); then
      CREATORLINE+="$creator"
      let "counter+=1"
    else 
      CREATORLINE+=", $creator"
    fi
  done
else
  CREATORLINE+="Creator: $CREATORS"
fi
set -u
echo $CREATORLINE >> $FILEID
echo $HASHTAGSTR >> $FILEID

cat $FILEID
echo "==="
echo $METADATA

#for testing without broadcasting.
#nak event -v --pow 1 -k 1 -c @$FILEID -t client="ArchiveStr" -t url=$UPLOADURL $METADATA --sec $NSECKEY

nak event -v --pow 28 -k 1 -c @$FILEID -t client="ArchiveStr" -t url=$UPLOADURL $METADATA --sec $NSECKEY ${RELAYS[@]}

echo "removing $FILEID"
rm ./$FILEID
echo "done!"
