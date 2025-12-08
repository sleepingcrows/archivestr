# ArchiveStr
**A very UNIX-y, minimalist tool for publishing and preserving digital art on Nostr**

ArchiveStr lets you upload images, videos, audio, or any file to Nostr in a clean, and automated fashion; using nothing but shell tools and your existing `.txt` metadata sidecars.

ArchiveStr follows the UNIX Philosophy of using existing tools to complete the task.


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
