#!/bin/bash

# Detect video titles in DVD VIDEO_TS folder
# Identifies VTS_XX sets and classifies them by size

set -euo pipefail

VIDEO_TS_DIR="${1:-}"
SIZE_THRESHOLD_MB=100

if [[ -z "$VIDEO_TS_DIR" ]]; then
    echo "Usage: detect-titles.sh <path-to-VIDEO_TS>"
    exit 1
fi

if [[ ! -d "$VIDEO_TS_DIR" ]]; then
    echo "Error: VIDEO_TS directory not found: $VIDEO_TS_DIR" >&2
    exit 1
fi

# Find all VTS_XX_0.IFO files (indicate title sets)
# Exclude VIDEO_TS.IFO (that's the menu file, not a title)
for ifo_file in "$VIDEO_TS_DIR"/VTS_*_0.IFO; do
    # Check if any files matched (avoid error if no matches)
    [[ -e "$ifo_file" ]] || continue

    # Extract title number (e.g., VTS_01_0.IFO -> 01)
    basename_file=$(basename "$ifo_file")
    title_num=$(echo "$basename_file" | sed -E 's/VTS_([0-9]+)_0\.IFO/\1/')

    # Calculate total size of all VOB files for this title
    # Exclude VTS_XX_0.VOB (menu/navigation)
    # Include VTS_XX_1.VOB, VTS_XX_2.VOB, etc.
    total_size=0
    for vob_file in "$VIDEO_TS_DIR"/VTS_${title_num}_[1-9]*.VOB; do
        [[ -e "$vob_file" ]] || continue
        # Get file size in bytes
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS: use stat -f%z
            size=$(stat -f%z "$vob_file")
        else
            # Linux: use stat -c%s
            size=$(stat -c%s "$vob_file")
        fi
        total_size=$((total_size + size))
    done

    # Convert to MB
    size_mb=$((total_size / 1024 / 1024))

    # Classify as Main_Video or Clip
    if [[ $size_mb -gt $SIZE_THRESHOLD_MB ]]; then
        type="Main_Video"
    else
        type="Clip"
    fi

    # Output: title_number size_mb type
    # Format: VTS_01 1900 Main_Video
    echo "VTS_${title_num} ${size_mb} ${type}"
done
