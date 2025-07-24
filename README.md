# Metadata Bridge

A macOS application for connecting monitor-recorded files with high-quality DIT footage in film production workflows.

## Problem Statement

In fast-paced on-set environments, editors frequently cut footage recorded live from monitors without embedded metadata. Reconnecting this roughcut to high-quality DIT footage is typically slow and manual.

Specific challenges:
* Editors cut with SDI monitor-recorded files using DaVinci Resolve (Free).
* These recordings contain burned-in metadata, but not real clip names or timecodes.
* When DIT delivers high-quality files later, relinking the timeline is impossible without a metadata bridge.

## Solution

Metadata Bridge solves this problem by:

1. Extracting metadata from monitor-recorded files, including:
   - Burned-in timecodes and clip names using OCR
   - Duration and other technical metadata
   
2. Extracting metadata from DIT files

3. Matching files based on multiple criteria:
   - Duration comparison
   - Timecode matching
   - Clip name matching
   - Visual similarity

4. Generating a metadata bridge that can be imported into DaVinci Resolve to automatically relink the timeline

## Features

- **File Selection**: Import both monitor-recorded files and DIT files
- **Automatic Metadata Extraction**: Extract timecodes, clip names, and other metadata
- **Intelligent Matching**: Match files based on multiple criteria with confidence scores
- **Export Options**:
  - DaVinci Resolve XML for direct import
  - CSV file for reference
  - Detailed report with all metadata

## Requirements

- macOS 11.0 or later
- Xcode 13.0 or later (for development)

## Development

This application is built using:
- SwiftUI for the user interface
- AVFoundation for media handling
- Vision framework for OCR
- Core Image for image processing

## License

Copyright © 2025 Akhil Maddali. All rights reserved.