#!/bin/bash
#ArchiveStr V2
#Note: Keeping comments verbose on this rebuild for now, need a mental map!
set -euo pipefail
#Need to convert Blossom Server lists to an array, make it fail gracefully.
REQUIRED=(
  NSECKEY
  BLOSSOMSRV
  )





#Unique Temp File, avoiding mangled 
FILEID=note.$$.tmp

