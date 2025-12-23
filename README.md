# DVD Batch Converter

Automated script to convert VHS-to-DVD discs to MP4 format for Windows PC playback.

## Overview

This tool processes up to 20 DVDs containing digitized VHS content in **HYBRID MODE**:
1. **Preserves original DVD files** - Complete VIDEO_TS folders for archival
2. **Creates modern MP4 files** - H.264 video + AAC audio for easy viewing
- 45-50% size reduction from original MPEG-2
- Windows-compatible file naming and structure
- Organized folders with metadata and cover art

## System Requirements

- macOS (tested on macOS 15.2)
- External DVD drive
- External hard drive for output (112 GB SanDisk in this case)
- ~25-30 minutes processing time per DVD
- ~3 GB free space per DVD (original + converted)

## Installation

Already installed:
- ✓ HandBrakeCLI 1.10.2
- ✓ ffmpeg 8.0.1
- ✓ uv (for Python script management)

## Usage

### Quick Start

1. Insert first DVD into external drive
2. Run the conversion script:
   ```bash
   cd ~/repos/dvd-batch-converter
   ./convert-dvd.sh
   ```
3. Follow the prompts to process each DVD

### What the Script Does

For each DVD:
1. Detects the DVD mount point
2. Extracts title from metadata (DiscMetaData.xml)
3. Creates output folders in both DVD_Originals/ and DVD_MP4s/
4. Copies complete VIDEO_TS folder to DVD_Originals/ (archival)
5. Scans for video titles (main video + clips)
6. Converts each title to MP4 using HandBrake → DVD_MP4s/
7. Copies cover art and metadata to both locations
8. Generates a manifest file
9. Ejects the DVD
10. Prompts for next DVD

### Output Structure

```
/Volumes/SanDisk/
├── DVD_Originals/               # Original DVD files (archival)
│   ├── DVD_01_NISHIHIRA_JENSEI/
│   │   ├── VIDEO_TS/            # Complete DVD structure (~2 GB)
│   │   ├── metadata.xml
│   │   ├── cover.jpg
│   │   └── disc-label.jpg
│   ├── DVD_02_[TITLE]/
│   ...
│   └── DVD_20_[TITLE]/
│
└── DVD_MP4s/                    # Converted MP4 files (daily use)
    ├── DVD_01_NISHIHIRA_JENSEI/
    │   ├── VTS_01_Main_Video.mp4    # ~850 MB (main video)
    │   ├── VTS_02_Clip.mp4          # ~30 MB
    │   ├── VTS_03_Clip.mp4          # ~30 MB
    │   ├── VTS_04_Clip.mp4          # ~28 MB
    │   ├── metadata.xml
    │   ├── cover.jpg
    │   ├── disc-label.jpg
    │   └── manifest.txt
    ├── DVD_02_[TITLE]/
    ...
    └── DVD_20_[TITLE]/
```

**On Windows PC:**
- **For easy viewing**: Browse `DVD_MP4s/` and double-click any MP4
- **For DVD playback**: Install VLC, right-click `VIDEO_TS` folder → "Play with VLC"
- **For archival**: `DVD_Originals/` preserves everything in case you need to re-convert later

## File Naming

- Folders: `DVD_XX_SANITIZED_TITLE` (e.g., `DVD_01_NISHIHIRA_JENSEI`)
- Videos: `VTS_XX_Type.mp4` where Type is either `Main_Video` or `Clip`
- Windows-safe: no special characters (`:*?"<>|`), spaces replaced with underscores

## Encoding Settings

- **Video**: H.264 (x264), 2500 kbps, multi-pass encoding
- **Audio**: AAC, 192 kbps, stereo
- **Container**: MP4 (optimized for streaming)
- **Quality**: Preserves DVD quality while reducing file size 50%

## Windows Compatibility

Output files are fully compatible with:
- Windows 10/11 Media Player
- VLC Media Player
- Windows Movies & TV app
- Any modern video player

The SanDisk drive format should be exFAT or NTFS for Windows compatibility. Check with:
```bash
diskutil info /Volumes/SanDisk | grep "File System"
```

## Troubleshooting

### DVD Not Detected
- Wait 5-10 seconds after inserting DVD
- Try ejecting and reinserting
- Check `/Volumes/` to see if it mounted with a different name

### Insufficient Disk Space
- Each DVD requires ~3 GB of free space (original + converted)
- Check available space: `df -h /Volumes/SanDisk`
- Delete old files or use a larger drive

### Conversion Failed
- Check log file in `logs/conversion-YYYYMMDD-HHMMSS.log`
- Corrupted VOB files will be logged and skipped
- Script continues with remaining titles

### Missing Metadata
- If `DiscMetaData.xml` is missing, script uses volume name
- You can manually edit folder names after conversion

## Testing Before Batch Processing

To test with just the current DVD without processing all 20:

1. Modify line 16 in `convert-dvd.sh`: change `MAX_DVDS=20` to `MAX_DVDS=1`
2. Run script
3. Verify output in both:
   - `/Volumes/SanDisk/DVD_Originals/DVD_01_[TITLE]/`
   - `/Volumes/SanDisk/DVD_MP4s/DVD_01_[TITLE]/`
4. Test MP4 playback in VLC
5. Change back to `MAX_DVDS=20` for full batch

## Time Estimates

- **Per DVD**: ~25-30 minutes
  - Copy original VIDEO_TS: ~1-2 min
  - Main video (1.9 GB): ~20-25 min
  - Clips (40 MB each): ~1 min each
  - Assets/metadata: <30 seconds

- **Full Batch (20 DVDs)**: ~8-10 hours
  - Encoding time: ~8-10 hours
  - User interaction time: ~10 minutes (inserting/ejecting DVDs)

## Storage Requirements

- **Input**: 20 DVDs × 2 GB = 40 GB
- **Output**:
  - Originals: 20 DVDs × 2 GB = ~40 GB
  - MP4s: 20 DVDs × ~1 GB = ~20-24 GB
  - **Total: ~60-64 GB**
- **SanDisk capacity**: 112 GB (sufficient space)

## Directory Structure

```
dvd-batch-converter/
├── convert-dvd.sh              # Main script
├── lib/
│   ├── extract-metadata.py     # Parse XML metadata (UTF-16)
│   ├── detect-titles.sh        # Scan VIDEO_TS for titles
│   └── verify-output.sh        # Verify MP4 output
├── logs/
│   └── conversion-*.log        # Detailed logs
└── README.md                   # This file
```

## Log Files

Detailed logs are saved to `logs/conversion-YYYYMMDD-HHMMSS.log` with:
- Timestamp for each operation
- DVD detection and metadata extraction
- Conversion progress (from HandBrake)
- Verification results
- Any errors or warnings

## Resuming After Interruption

If the script is interrupted (Ctrl+C, system sleep, etc.):

1. Note which DVD number was being processed
2. Restart the script
3. It will prompt for DVD 1
4. You can skip already-converted DVDs by choosing 'N' when asked to continue

Note: The script currently processes sequentially. Manual tracking of progress is needed if interrupted.

## After Conversion

1. Safely eject SanDisk drive: `diskutil eject /Volumes/SanDisk`
2. Connect to Windows PC
3. Navigate to drive, each DVD is in its own folder
4. Double-click any MP4 in `DVD_MP4s/` to play in Windows Media Player
5. Use VLC to play original VIDEO_TS folders from `DVD_Originals/`
6. Cover art and metadata are in each folder for reference

## Support

For issues:
1. Check log files in `logs/`
2. Verify disk space: `df -h /Volumes/SanDisk`
3. Test HandBrake manually: `HandBrakeCLI --version`
4. Verify DVD mount: `ls -la /Volumes/`

## Notes

- Original DVDs are not modified (read-only)
- Conversion is lossy but preserves DVD quality
- Multi-pass encoding ensures optimal quality/size ratio
- Script can be paused between DVDs
- Each DVD folder is self-contained
- Both original and converted formats are preserved
