#!/bin/bash

# DVD Batch Converter - Convert VHS-to-DVD discs to MP4 format
# Processes 20 DVDs sequentially with user prompts

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="/Volumes/SanDisk"
ORIGINALS_DIR="$TARGET_DIR/DVD_Originals"
MP4_DIR="$TARGET_DIR/DVD_MP4s"
MAX_DVDS=20
MIN_SPACE_GB=3
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/conversion-$(date +%Y%m%d-%H%M%S).log"
STATE_FILE="$TARGET_DIR/.conversion-state.json"

# Helper scripts
EXTRACT_METADATA="$SCRIPT_DIR/lib/extract-metadata.py"
DETECT_TITLES="$SCRIPT_DIR/lib/detect-titles.sh"
VERIFY_OUTPUT="$SCRIPT_DIR/lib/verify-output.sh"
HANDBRAKE_PRESET="$SCRIPT_DIR/config/handbrake-preset.json"

# ============================================================================
# Logging and UI Functions
# ============================================================================

log() {
    local message="$1"
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $message" | tee -a "$LOG_FILE"
}

log_error() {
    local message="$1"
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] ERROR: $message" | tee -a "$LOG_FILE" >&2
}

print_header() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           DVD Batch Converter - DVD $1/$2                   "
    echo "╠══════════════════════════════════════════════════════════════╣"
}

print_footer() {
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

# ============================================================================
# DVD Detection
# ============================================================================

detect_dvd_mount() {
    # Try common mount point patterns
    for mount_point in /Volumes/Yesvideo /Volumes/YESVIDEO /Volumes/YesVideo /Volumes/DVD*; do
        if [[ -d "$mount_point/VIDEO_TS" ]]; then
            echo "$mount_point"
            return 0
        fi
    done

    # Fallback: check all volumes for VIDEO_TS
    for vol in /Volumes/*; do
        if [[ -d "$vol/VIDEO_TS" ]]; then
            echo "$vol"
            return 0
        fi
    done

    return 1
}

wait_for_dvd() {
    local timeout=60
    local elapsed=0

    echo "Waiting for DVD mount (timeout: ${timeout}s)..." >&2

    while [[ $elapsed -lt $timeout ]]; do
        if dvd_mount=$(detect_dvd_mount); then
            echo "✓ DVD detected: $dvd_mount" >&2
            echo "$dvd_mount"
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done

    log_error "DVD mount not detected after ${timeout}s"
    return 1
}

# ============================================================================
# Disk Space Check
# ============================================================================

check_disk_space() {
    local required_gb=$1

    # Get available space in GB (macOS)
    local available_blocks=$(df -g "$TARGET_DIR" | awk 'NR==2 {print $4}')
    local available_gb=$available_blocks

    if [[ $available_gb -lt $required_gb ]]; then
        log_error "Insufficient disk space: ${available_gb}GB available, ${required_gb}GB required"
        return 1
    fi

    log "Disk space check passed: ${available_gb}GB available"
    return 0
}

# ============================================================================
# Conversion Functions
# ============================================================================

extract_metadata_from_dvd() {
    local dvd_mount=$1
    local metadata_file="$dvd_mount/DiscMetaData.xml"

    if [[ ! -f "$metadata_file" ]]; then
        log_error "DiscMetaData.xml not found, using volume name"
        basename "$dvd_mount"
        return 0
    fi

    uv run "$EXTRACT_METADATA" "$metadata_file" --sanitize
}

convert_title() {
    local dvd_mount=$1
    local title_num=$2
    local output_file=$3
    local vts_name=$4

    log "Converting $vts_name (title $title_num)..."

    # Run HandBrakeCLI with direct command-line arguments
    if HandBrakeCLI \
        --input "$dvd_mount/VIDEO_TS" \
        --title "$title_num" \
        --output "$output_file" \
        --encoder x264 \
        --vb 2500 \
        --multi-pass \
        -T \
        --audio 1 \
        --aencoder av_aac \
        --ab 192 \
        --mixdown stereo \
        --format mp4 \
        --optimize \
        2>&1 | tee -a "$LOG_FILE"; then

        log "✓ Conversion complete: $output_file"
        return 0
    else
        log_error "Conversion failed for $vts_name"
        return 1
    fi
}

verify_conversion() {
    local mp4_file=$1

    if "$VERIFY_OUTPUT" "$mp4_file" >> "$LOG_FILE" 2>&1; then
        return 0
    else
        log_error "Verification failed: $mp4_file"
        return 1
    fi
}

copy_original_dvd() {
    local dvd_mount=$1
    local output_dir=$2

    log "Copying original DVD structure..."

    # Copy entire VIDEO_TS folder
    if [[ -d "$dvd_mount/VIDEO_TS" ]]; then
        cp -R "$dvd_mount/VIDEO_TS" "$output_dir/"
        log "✓ Copied VIDEO_TS folder ($(du -sh "$output_dir/VIDEO_TS" | awk '{print $1}'))"
    fi

    # Copy metadata and images
    if [[ -f "$dvd_mount/DiscMetaData.xml" ]]; then
        cp "$dvd_mount/DiscMetaData.xml" "$output_dir/metadata.xml"
        log "✓ Copied metadata.xml"
    fi

    if [[ -f "$dvd_mount/Sheet/sheet.jpg" ]]; then
        cp "$dvd_mount/Sheet/sheet.jpg" "$output_dir/cover.jpg"
        log "✓ Copied cover.jpg"
    elif [[ -f "$dvd_mount/sheet/sheet.jpg" ]]; then
        cp "$dvd_mount/sheet/sheet.jpg" "$output_dir/cover.jpg"
        log "✓ Copied cover.jpg"
    fi

    if [[ -f "$dvd_mount/discsurface/discsurface.jpg" ]]; then
        cp "$dvd_mount/discsurface/discsurface.jpg" "$output_dir/disc-label.jpg"
        log "✓ Copied disc-label.jpg"
    fi
}

copy_assets() {
    local dvd_mount=$1
    local output_dir=$2

    log "Copying metadata and assets..."

    # Copy metadata XML
    if [[ -f "$dvd_mount/DiscMetaData.xml" ]]; then
        cp "$dvd_mount/DiscMetaData.xml" "$output_dir/metadata.xml"
        log "✓ Copied metadata.xml"
    fi

    # Copy cover art
    if [[ -f "$dvd_mount/Sheet/sheet.jpg" ]]; then
        cp "$dvd_mount/Sheet/sheet.jpg" "$output_dir/cover.jpg"
        log "✓ Copied cover.jpg"
    elif [[ -f "$dvd_mount/sheet/sheet.jpg" ]]; then
        cp "$dvd_mount/sheet/sheet.jpg" "$output_dir/cover.jpg"
        log "✓ Copied cover.jpg"
    else
        log "Warning: cover.jpg not found"
    fi

    # Copy disc label
    if [[ -f "$dvd_mount/discsurface/discsurface.jpg" ]]; then
        cp "$dvd_mount/discsurface/discsurface.jpg" "$output_dir/disc-label.jpg"
        log "✓ Copied disc-label.jpg"
    else
        log "Warning: disc-label.jpg not found"
    fi
}

generate_manifest() {
    local output_dir=$1
    local dvd_title=$2
    local manifest_file="$output_dir/manifest.txt"

    {
        echo "DVD Conversion Manifest"
        echo "======================="
        echo ""
        echo "Title: $dvd_title"
        echo "Conversion Date: $(date)"
        echo "HandBrake Version: $(HandBrakeCLI --version 2>&1 | head -1)"
        echo ""
        echo "Video Files:"
        echo "------------"
        for mp4 in "$output_dir"/*.mp4; do
            [[ -e "$mp4" ]] || continue
            local size_mb=$(stat -f%z "$mp4" | awk '{print int($1/1024/1024)}')
            local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$mp4" 2>/dev/null || echo "0")
            local duration_min=$(printf "%.1f" $(echo "$duration / 60" | bc -l))
            echo "  $(basename "$mp4"): ${size_mb}MB, ${duration_min}min"
        done
    } > "$manifest_file"

    log "✓ Generated manifest.txt"
}

# ============================================================================
# Main Conversion Workflow
# ============================================================================

process_dvd() {
    local dvd_num=$1
    local dvd_mount

    print_header "$dvd_num" "$MAX_DVDS"

    # Wait for DVD if not already mounted
    if ! dvd_mount=$(detect_dvd_mount); then
        echo "║  Please insert DVD $dvd_num and press Enter...             "
        print_footer
        read -r
        if ! dvd_mount=$(wait_for_dvd); then
            log_error "Failed to detect DVD $dvd_num"
            return 1
        fi
    fi

    log "Processing DVD $dvd_num/$MAX_DVDS from $dvd_mount"

    # Extract metadata
    local title_sanitized
    title_sanitized=$(extract_metadata_from_dvd "$dvd_mount")
    local folder_name="DVD_$(printf '%02d' "$dvd_num")_${title_sanitized}"
    local originals_output="$ORIGINALS_DIR/$folder_name"
    local mp4_output="$MP4_DIR/$folder_name"

    log "Output folders: $folder_name"
    echo "║  Title: $title_sanitized"
    echo "║  Originals: $originals_output"
    echo "║  MP4s: $mp4_output"
    echo "╠══════════════════════════════════════════════════════════════╣"

    # Check if folders already exist
    if [[ -d "$originals_output" ]] || [[ -d "$mp4_output" ]]; then
        log_error "Output folders already exist"
        echo "║  ERROR: Folders already exist. Overwrite? [y/N]"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log "Skipping DVD $dvd_num"
            return 1
        fi
        rm -rf "$originals_output" "$mp4_output"
    fi

    # Create output directories
    mkdir -p "$originals_output"
    mkdir -p "$mp4_output"

    # Check disk space (need more for both copies)
    if ! check_disk_space "$MIN_SPACE_GB"; then
        log_error "Insufficient disk space"
        return 1
    fi

    # Step 1: Copy original DVD structure
    echo "║  Step 1: Copying original DVD files..."
    copy_original_dvd "$dvd_mount" "$originals_output"
    echo "║  ✓ Original DVD copied"
    echo "╠══════════════════════════════════════════════════════════════╣"

    # Step 2: Convert to MP4
    echo "║  Step 2: Converting to MP4 format..."
    log "Detecting video titles..."
    local titles_info
    titles_info=$("$DETECT_TITLES" "$dvd_mount/VIDEO_TS")

    local title_count=$(echo "$titles_info" | wc -l | tr -d ' ')
    log "Found $title_count video titles"

    # Convert each title
    local converted_count=0
    local failed_count=0

    while IFS= read -r line; do
        # Parse: VTS_01 1873 Main_Video
        local vts_name=$(echo "$line" | awk '{print $1}')
        local size_mb=$(echo "$line" | awk '{print $2}')
        local type=$(echo "$line" | awk '{print $3}')

        # Extract title number (VTS_01 -> 1)
        local title_num=$(echo "$vts_name" | sed 's/VTS_0*//')

        local output_file="$mp4_output/${vts_name}_${type}.mp4"

        echo "║  Converting ${vts_name} (${type}) - ${size_mb}MB"

        if convert_title "$dvd_mount" "$title_num" "$output_file" "$vts_name"; then
            if verify_conversion "$output_file"; then
                converted_count=$((converted_count + 1))
                echo "║    ✓ Complete"
            else
                failed_count=$((failed_count + 1))
                echo "║    ✗ Verification failed"
            fi
        else
            failed_count=$((failed_count + 1))
            echo "║    ✗ Conversion failed"
        fi
    done <<< "$titles_info"

    # Copy assets to MP4 folder
    echo "╠══════════════════════════════════════════════════════════════╣"
    copy_assets "$dvd_mount" "$mp4_output"

    # Generate manifest for MP4 folder
    generate_manifest "$mp4_output" "$title_sanitized"

    # Summary
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  Summary:"
    echo "║    Converted: $converted_count/$title_count MP4s"
    if [[ $failed_count -gt 0 ]]; then
        echo "║    Failed: $failed_count"
    fi

    local originals_size=$(du -sh "$originals_output" | awk '{print $1}')
    local mp4_size=$(du -sh "$mp4_output" | awk '{print $1}')
    echo "║    Original DVD: $originals_size"
    echo "║    MP4 files: $mp4_size"
    print_footer

    # Eject DVD
    log "Ejecting DVD..."
    diskutil eject "$dvd_mount" >> "$LOG_FILE" 2>&1 || true

    return 0
}

# ============================================================================
# Main Entry Point
# ============================================================================

main() {
    # Create log directory
    mkdir -p "$LOG_DIR"

    log "========================================="
    log "DVD Batch Converter Started"
    log "========================================="

    # Pre-flight checks
    log "Running pre-flight checks..."

    # Check if target drive exists
    if [[ ! -d "$TARGET_DIR" ]]; then
        log_error "Target drive not found: $TARGET_DIR"
        echo "Error: External drive (SanDisk) not mounted at $TARGET_DIR"
        exit 1
    fi

    # Check required tools
    for tool in HandBrakeCLI ffprobe uv; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool not found: $tool"
            echo "Error: $tool is not installed"
            exit 1
        fi
    done

    log "✓ Pre-flight checks passed"

    # Check disk format
    log "Target drive format:"
    diskutil info "$TARGET_DIR" | grep "File System" | tee -a "$LOG_FILE"

    # Create main directories
    mkdir -p "$ORIGINALS_DIR"
    mkdir -p "$MP4_DIR"
    log "Created output directories"

    # Set starting DVD number
    local start_dvd=11

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              DVD Batch Converter (Hybrid Mode)              ║"
    echo "║                                                              ║"
    echo "║  This script will process DVDs $start_dvd-$MAX_DVDS:                      ║"
    echo "║    1. Copy original DVD files (VIDEO_TS folders)           ║"
    echo "║    2. Convert to MP4 format (H.264 + AAC)                  ║"
    echo "║                                                              ║"
    echo "║  Output:                                                    ║"
    echo "║    Originals: $ORIGINALS_DIR          ║"
    echo "║    MP4s:      $MP4_DIR                 ║"
    echo "║                                                              ║"
    echo "║  Press Enter to start, or Ctrl+C to cancel                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    read -r

    # Process DVDs sequentially
    local success_count=0

    for dvd_num in $(seq "$start_dvd" "$MAX_DVDS"); do
        if process_dvd "$dvd_num"; then
            success_count=$((success_count + 1))
            log "DVD $dvd_num/$MAX_DVDS completed successfully"
        else
            log_error "DVD $dvd_num/$MAX_DVDS failed"
            echo ""
            echo "Continue with next DVD? [y/N]"
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                log "Batch conversion cancelled by user"
                break
            fi
        fi

        # Don't prompt for next DVD if this is the last one
        if [[ $dvd_num -lt $MAX_DVDS ]]; then
            echo ""
            echo "Ready for DVD $((dvd_num + 1))? [Y/n]"
            read -r response
            if [[ "$response" =~ ^[Nn]$ ]]; then
                log "Batch conversion paused by user"
                break
            fi
        fi
    done

    # Final summary
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              Batch Conversion Complete                      ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  Successfully converted: $success_count/$MAX_DVDS DVDs"
    echo "║  Output location: $TARGET_DIR"
    echo "║  Log file: $LOG_FILE"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    log "========================================="
    log "Batch conversion complete: $success_count/$MAX_DVDS DVDs"
    log "========================================="
}

# Run main function
main "$@"
