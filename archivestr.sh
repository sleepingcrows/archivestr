#!/bin/bash
set -euo pipefail
: ${1?"Usage: $0 <path to file>
(every file needs a .txt sidecar with a rating and creator namespace at minimum!)"}
REQUIRED=(
  NSECKEY
  BLOSSOMSRV
  BLOSSOMSRV2
  BLOSSOMSRV3
  )

if [[ -f .env ]]; then
  set -a 
  source .env
  set +a 
fi 

FILEID=note.$$.tmp

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

#need to make tag processing arbitrary.
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

CONTENT=""

echo ===Uploading File to $BLOSSOMSRV===
UPLOADURL=$(nak blossom --server $BLOSSOMSRV --sec 01 upload $1 | jq .url | sed 's/\"//g')
echo $UPLOADURL
echo "===Uploading File to $BLOSSOMSRV2 -- Mirror 1 ==="
nak blossom --server $BLOSSOMSRV2 --sec 01 upload $1 | jq .url | sed 's/\"//g'
echo "===Uploading File to $BLOSSOMSRV3 -- Mirror 2 ==="
nak blossom --server $BLOSSOMSRV3 --sec 01 upload $1 | jq .url | sed 's/\"//g'
 
echo $UPLOADURL > $FILEID

METADATA=""

set +u
if [[ ! " ${RATINGS[@]} " =~ " safe " ]]; then
  METADATA+="-t content-warning=nsfw -t rating=$RATINGS "
else
  METADATA+="-t rating=$RATINGS "  
fi
set -u
counter=0
set +u
if [ ${#CREATORS[@]} -gt 1 ]; then
  CONTENT+="Creators: "
  for creator in "${CREATORS[@]}"; do
    if (( counter == 0 )); then
      CONTENT+="$creator"
      let "counter+=1"
    else
      CONTENT+=", $creator"
    fi
    clean=$(printf '%s' "$creator" | sed 's/ /_/g')
    METADATA+="-t creator=$clean "
  done
else
  CONTENT+="Creator: "
  CONTENT+="$CREATORS"
  clean=$(printf '%s' "$CREATORS" | sed 's/ /_/g')
  METADATA+="-t creator=$clean "
fi
set -u
echo $CONTENT >> $FILEID
HASHTAGS=""

#Bash seems to act pretty dumb when trying to pool together many arrays. Maybe I'm just dumb.
#Violating DRY for this.

for tag in "${SPECIES[@]}"; do 
  [[ -z "$tag" ]] && continue
  clean=$(printf '%s' "$tag" | sed 's/ /_/g')
  HASHTAGS+="#$clean "
  METADATA+="-t species=$clean "
done

for tag in "${SERIES[@]}"; do 
  [[ -z "$tag" ]] && continue
  clean=$(printf '%s' "$tag" | sed 's/ /_/g')
  HASHTAGS+="#$clean "
  METADATA+="-t series=$clean "
done

for tag in "${CHARACTERS[@]}"; do 
  [[ -z "$tag" ]] && continue
  clean=$(printf '%s' "$tag" | sed 's/ /_/g')
  HASHTAGS+="#$clean "
  METADATA+="-t character=$clean "
done

for tag in "${TAGS[@]}"; do 
  [[ -z "$tag" ]] && continue
  clean=$(printf '%s' "$tag" | sed 's/ /_/g')
  HASHTAGS+="#$clean "
  METADATA+="-t t=$clean "
done

echo $HASHTAGS >> $FILEID

#note cleanup.

sed -i '3s/[()]//g; 3s/[:!.-]/_/g' $FILEID

#nak event -v -k 1 --pow 28 -c @$FILEID -t client="ArchiveStr" -t url=$UPLOADURL $METADATA --sec $NSECKEY ${RELAYS[@]}

#cleanup after yourself.
#rm $FILEID
