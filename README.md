# ArchiveStr
### A very UNIX-y way of art preservation for Nostr.

**Requirements**
```
sed
grep
nak (github.com/fiatjaf/nak)
jq
```
**Usage**
```
Usage: ./archivestr.sh <path to file> (must have a .txt tag sidecar)
```

**txt Sidecars**
* prefixed with the same name as the target file. (example.jpg.txt)
* Sidecar must contain at least 1 creator/artist (creator:anonymous)
* Sidecar must contain only 1 safety rating (rating:safe, rating:questionable, etc.)
* Any sidecar not containing `rating:safe` will automatically be appended a content warning tag.
