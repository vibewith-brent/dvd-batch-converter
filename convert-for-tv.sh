#!/bin/bash

# Convert existing MP4s to TV-compatible format
# Creates copies with H.264 Main profile for better USB playback compatibility

set -euo pipefail

FFMPEG="/opt/homebrew/Cellar/ffmpeg/8.0.1/bin/ffmpeg"
FFPROBE="/opt/homebrew/Cellar/ffmpeg/8.0.1/bin/ffprobe"

SOURCE_DIR="/Volumes/SanDisk/DVD_MP4s"
OUTPUT_DIR="/Volumes/SanDisk/DVD_TV"

# Check prerequisites
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: Source directory not found: $SOURCE_DIR"
    exit 1
fi

if [[ ! -x "$FFMPEG" ]]; then
    echo "Error: ffmpeg not found at $FFMPEG"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Count files
total=$(find "$SOURCE_DIR" -name "*.mp4" ! -name "._*" | wc -l | tr -d ' ')
current=0

echo "================================================"
echo "  TV-Compatible MP4 Converter"
echo "================================================"
echo "Source: $SOURCE_DIR"
echo "Output: $OUTPUT_DIR"
echo "Files to convert: $total"
echo ""
echo "Settings:"
echo "  - H.264 Main profile (better TV compatibility)"
echo "  - Level 4.0"
echo "  - CRF 18 (high quality)"
echo "  - Audio: copy (no re-encode)"
echo "================================================"
echo ""
read -p "Press Enter to start, or Ctrl+C to cancel..."
echo ""

# Process each DVD folder
for dvd_folder in "$SOURCE_DIR"/DVD_*; do
    [[ -d "$dvd_folder" ]] || continue

    folder_name=$(basename "$dvd_folder")
    out_folder="$OUTPUT_DIR/$folder_name"
    mkdir -p "$out_folder"

    # Process MP4 files in this folder
    for mp4_file in "$dvd_folder"/*.mp4; do
        [[ -f "$mp4_file" ]] || continue
        [[ "$(basename "$mp4_file")" == ._* ]] && continue

        current=$((current + 1))
        filename=$(basename "$mp4_file")
        output_file="$out_folder/$filename"

        # Skip if already converted
        if [[ -f "$output_file" ]]; then
            echo "[$current/$total] Skipping (exists): $folder_name/$filename"
            continue
        fi

        echo "[$current/$total] Converting: $folder_name/$filename"

        # Get duration for progress
        duration=$("$FFPROBE" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$mp4_file" 2>/dev/null || echo "0")
        duration_min=$(printf "%.1f" "$(echo "$duration / 60" | bc -l 2>/dev/null || echo "0")")
        echo "         Duration: ${duration_min} min"

        # Convert with TV-compatible settings
        if "$FFMPEG" -i "$mp4_file" \
            -c:v libx264 \
            -profile:v main \
            -level 4.0 \
            -preset medium \
            -crf 18 \
            -pix_fmt yuv420p \
            -c:a copy \
            -movflags +faststart \
            -y \
            "$output_file" \
            2>/dev/null; then

            # Verify output
            if [[ -f "$output_file" ]] && [[ $(stat -f%z "$output_file") -gt 1000000 ]]; then
                out_size=$(du -h "$output_file" | awk '{print $1}')
                echo "         ✓ Complete: $out_size"
            else
                echo "         ✗ Failed: output file invalid"
                rm -f "$output_file"
            fi
        else
            echo "         ✗ Conversion failed"
            rm -f "$output_file"
        fi
    done

    # Copy cover image if exists (TVs often show thumbnails)
    if [[ -f "$dvd_folder/cover.jpg" ]] && [[ ! -f "$out_folder/cover.jpg" ]]; then
        cp "$dvd_folder/cover.jpg" "$out_folder/"
    fi
done

echo ""
echo "================================================"
echo "  Conversion Complete"
echo "================================================"
echo "Output: $OUTPUT_DIR"
du -sh "$OUTPUT_DIR"
echo ""
echo "TV playback tips:"
echo "  - Eject and re-insert the drive"
echo "  - Look in the DVD_TV folder"
echo "  - If still not working, try renaming .mp4 to .m4v"
echo "================================================"
