#!/bin/bash
#ArchiveStr V2
#Note: Keeping comments verbose on this rebuild for now, need a mental map!
set -euo pipefail
#Need to convert Blossom Server lists to an array, make it fail gracefully.
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


