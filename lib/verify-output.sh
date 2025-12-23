#!/bin/bash

# Verify MP4 output file after conversion
# Checks codec, file size, and basic stream integrity

set -euo pipefail

MP4_FILE="${1:-}"
MIN_SIZE_MB=1

if [[ -z "$MP4_FILE" ]]; then
    echo "Usage: verify-output.sh <path-to-mp4-file>"
    exit 1
fi

if [[ ! -f "$MP4_FILE" ]]; then
    echo "Error: MP4 file not found: $MP4_FILE" >&2
    exit 1
fi

# Check file size
if [[ "$OSTYPE" == "darwin"* ]]; then
    size_bytes=$(stat -f%z "$MP4_FILE")
else
    size_bytes=$(stat -c%s "$MP4_FILE")
fi

size_mb=$((size_bytes / 1024 / 1024))

if [[ $size_mb -lt $MIN_SIZE_MB ]]; then
    echo "Error: File too small ($size_mb MB < $MIN_SIZE_MB MB)" >&2
    exit 1
fi

# Use ffprobe to verify codec and stream info
if ! command -v ffprobe &> /dev/null; then
    echo "Warning: ffprobe not found, skipping codec verification" >&2
    exit 0
fi

# Extract video and audio codec info
video_codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$MP4_FILE" 2>/dev/null || echo "unknown")
audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$MP4_FILE" 2>/dev/null || echo "unknown")
duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$MP4_FILE" 2>/dev/null || echo "0")

# Verify expected codecs
if [[ "$video_codec" != "h264" ]]; then
    echo "Warning: Video codec is $video_codec (expected h264)" >&2
fi

if [[ "$audio_codec" != "aac" ]]; then
    echo "Warning: Audio codec is $audio_codec (expected aac)" >&2
fi

# Duration should be > 0
duration_int=$(printf "%.0f" "$duration")
if [[ $duration_int -lt 1 ]]; then
    echo "Error: Invalid duration ($duration seconds)" >&2
    exit 1
fi

# All checks passed
echo "✓ Verification passed"
echo "  Size: $size_mb MB"
echo "  Video: $video_codec"
echo "  Audio: $audio_codec"
echo "  Duration: $duration_int seconds"
exit 0
