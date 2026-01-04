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

for var in "${REQUIRED[@]}" do 
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


#pre-process logic: check if "creator" and "rating" exist, exit if one of them is missing. 

#Tag Processing Logic (The major rewrite.)
#Process: Read sidecar line by line in Loop.
# 1. check for ':' exists in the line, telling us it's namespaced.
# a1. If ':' Exists: find what character it is, store that position.
# a2. Seperate namespace and tag, store them
# b1. If ':' Absent: assume it's a regular tag.
# b2. store namespace as 'tag', store the tag.
# 2. check if the namespace is special (creator, rating)
# 2a. If special, Perform special operations
# 2a.1. Creator: add this to a special array.
# 2a.2. Rating: Check if it's anything but 'safe', set a flag for later.
# 3. Execute tag generation logic.
# 3a. Add the URL to the tmp file, then add a new line for the creator(s). check if it is one, or more to decide
# what format should be used.
# 3b. append 'hashtag', with tag sanitization. (#tag_example) to a string variable.
# 3c. append the key pair value (key=value) to an array.
# 4. append the hashtag string variable to the temp file.
