#!/bin/bash
#PBS -e /dev/null
#PBS -o /dev/null
set -euo pipefail
IFS=$'\n\t'

# BLEND_FILE_PATH is expected to be an absolute path to a valid .blend file

function blend_file() {
  (
    set +u  # allow using environment variables
    echo "$BLEND_FILE_PATH" | perl -pe 's[.+/][]'
  )
}

function blend_path() {
  (
    set +u  # allow using environment variables
    echo "$BLEND_FILE_PATH" | perl -pe 's[^(.+)/.+][\1]'
  )
}

function output_dir() {
  (
    set +u  # allow using environment variables
    echo "$OUTPUT_DIR" | perl -pe 's[.+/][]'
  )
}

function frames_range() {
  (
    set +u  # allow using environment variables
    echo "$FRAMES_RANGE" | perl -pe 's[.+/][]'
  )
}

# Use LMod to load Blender into our PATH
module load blender
(
  # Change directory to where our .blend file is
  cd "$(blend_path)"
  
  env | grep -P '^[A-Z]' | sort

  blend_file
  blend_path

  # Ensure that the output directory exists
  mkdir -p "$(output_dir)"
  # Call blender on our blend
  #   -b which blend to work on
  #   -F sets the file format
  #   -o sets the output directory; defaults to /tmp
  #   -x allows blender to set the file extension
  #   -t 0 allows blender to use as many threads as there are processors
  #   -a render all scenes in the blend
  blender \
    -b "$(blend_file)" \
    -F PNG \
    -o //"$(output_dir)"/render_ \
    -x 1 \
    -t 0 \
    -f "$(frames_range)" # renders frames 1-10, -f 1,3,5 renders frames 1, 3 and 5...
)

