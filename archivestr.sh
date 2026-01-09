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
  )

if [[ -f .env ]]; then
  set -a
  source .env 
  set +a 
fi

#Unique Temp File, avoiding mangled 
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
#TAGS=() #key value pairs.
declare -A taglist
HASHTAGS=() #sanitized tags.

append_to_taglist () {
  key="$1"
  value="$2"
#  if [[ ! ${taglist[$key]+isset} ]]; then
#    taglist[${key}]=
#  fi

  taglist[$key]+="$value,"
}

#pre-process logic: check if "creator" and "rating" exist, exit if one of them is missing. 
while IFS=':' read -r namespace tag; do 
  if [ -z "$tag" ]; then
    tag="$namespace"
    namespace="tag"
  fi
  #echo "namespace: $namespace | tag: $tag"
  #check if it's a special namespace (creator, rating)
  if [ "$namespace" = "creator" ]; then
    echo "namespace was a creator"
    CREATORS+=$tag
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
fi



# upload the file, store the returned URL 
# Temp method, does not mirror to multiple services.
echo ===Uploading File to $BLOSSOMSRV===
UPLOADURL=$(nak blossom --server $BLOSSOMSRV --sec 01 upload $1 | jq .url | sed 's/\"//g')
echo $UPLOADURL
# start creating the temp file content.
# > File URL
# > Creator(s)
# > all Tags as hashtags, sanitized without namespaces, spaces converted to underscores, and symbols stripped.
# > create all of the keypairs.
# > broadcast.

touch $FILEID

echo $UPLOADURL > $FILEID
echo ===
cat $FILEID
#this only injects the raw tags in newlines and dumps them directly to the temp file.
#need to parse each value and add them into a long string before dumping them in.
for key in "${!taglist[@]}"; do 
  IFS=',' read -r -a values <<< "${taglist[$key]}"
  for value in "${values[@]}"; do
    echo "#$value" >> $FILEID
  done
done

#Tag Processing Logic (The major rewrite.)
#Process: Read sidecar line by line in Loop.
# 2. check if the namespace is special (creator, rating)
# 2a. If special, Perform special operations
# 2a.1. Creator: add this to a special array.
# 2a.2. Rating: Check if it's anything but 'safe', set a flag for later.
# 3. Execute tag generation logic.
# 3a. Add the URL to the tmp file, then add a new line for the creator(s). check if it is one, or more to decide
# what format should be used.
# 3b. append 'hashtag', with tag sanitization. (#tag_example) to a string variable. (should we store a t=value too?)
# 3c. append the key pair value (key=value) to an array.
# 4. append the hashtag string variable to the temp file.

