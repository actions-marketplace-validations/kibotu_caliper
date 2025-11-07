#!/bin/bash

# Caliper IPA Analysis Script
# This script unzips an IPA and analyzes it with Caliper

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
info() {
    echo -e "${GREEN}ℹ${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check arguments
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <ipa-path> [link-map-path] [ownership-yml] [filter-owner]"
    echo ""
    echo "Examples:"
    echo "  $0 MyApp.ipa"
    echo "  $0 MyApp.ipa path/to/LinkMap.txt"
    echo "  $0 MyApp.ipa path/to/LinkMap.txt module-ownership.yml"
    echo "  $0 MyApp.ipa path/to/LinkMap.txt module-ownership.yml core"
    exit 1
fi

IPA_PATH="$1"
LINK_MAP_PATH="${2:-}"
OWNERSHIP_FILE="${3:-}"
FILTER_OWNER="${4:-}"

# Check if IPA exists
if [ ! -f "$IPA_PATH" ]; then
    error "IPA file not found: $IPA_PATH"
fi

# Get IPA filename without extension
IPA_NAME=$(basename "$IPA_PATH" .ipa)
UNZIPPED_DIR="${IPA_NAME}_unzipped"

info "Analyzing IPA: $IPA_PATH"

# Clean up previous unzipped directory if exists
if [ -d "$UNZIPPED_DIR" ]; then
    warning "Removing existing unzipped directory: $UNZIPPED_DIR"
    rm -rf "$UNZIPPED_DIR"
fi

# Unzip IPA
info "Unzipping IPA to: $UNZIPPED_DIR"
unzip -q "$IPA_PATH" -d "$UNZIPPED_DIR"

# Build Caliper if needed
CALIPER_BIN=".build/release/Caliper"
if [ ! -f "$CALIPER_BIN" ]; then
    info "Building Caliper (release mode)..."
    swift build -c release
fi

# Prepare Caliper command
CALIPER_CMD="$CALIPER_BIN --ipa-path \"$IPA_PATH\" --unzipped-path \"$UNZIPPED_DIR\" --pretty-print"

# Only group by owner if we have an ownership file
if [ -n "$OWNERSHIP_FILE" ] && [ -f "$OWNERSHIP_FILE" ]; then
    CALIPER_CMD="$CALIPER_CMD --group-by-owner"
fi

# Add optional parameters
if [ -n "$LINK_MAP_PATH" ]; then
    if [ ! -f "$LINK_MAP_PATH" ]; then
        warning "LinkMap file not found: $LINK_MAP_PATH (continuing without it)"
    else
        info "Using LinkMap: $LINK_MAP_PATH"
        CALIPER_CMD="$CALIPER_CMD --link-map-path \"$LINK_MAP_PATH\""
    fi
fi

if [ -n "$OWNERSHIP_FILE" ]; then
    if [ ! -f "$OWNERSHIP_FILE" ]; then
        warning "Ownership file not found: $OWNERSHIP_FILE (using defaults)"
    else
        info "Using ownership file: $OWNERSHIP_FILE"
        CALIPER_CMD="$CALIPER_CMD --ownership-file \"$OWNERSHIP_FILE\""
    fi
fi

if [ -n "$FILTER_OWNER" ]; then
    info "Filtering modules for owner: $FILTER_OWNER"
    CALIPER_CMD="$CALIPER_CMD --filter-owner \"$FILTER_OWNER\""
fi

# Run Caliper
info "Running Caliper analysis..."
echo ""

# Output file
OUTPUT_FILE="${IPA_NAME}-report.json"

# Run Caliper and save ONLY JSON output to file
# stderr (progress/warnings) stays in terminal
eval "$CALIPER_CMD" > "$OUTPUT_FILE"

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    info "✅ Analysis complete!"
    echo ""
    echo "📊 Report saved to: $OUTPUT_FILE"
    
    # Show file size
    REPORT_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo "📦 Report size: $REPORT_SIZE"
    
    # Show summary
    echo ""
    info "Summary:"
    
    # Try to extract key metrics using jq if available
    if command -v jq &> /dev/null; then
        TOTAL_PACKAGE=$(jq -r '.totalPackageSize' "$OUTPUT_FILE" 2>/dev/null)
        TOTAL_INSTALL=$(jq -r '.totalInstallSize' "$OUTPUT_FILE" 2>/dev/null)
        MODULE_COUNT=$(jq -r '.modules | length' "$OUTPUT_FILE" 2>/dev/null)
        
        if [ "$TOTAL_PACKAGE" != "null" ] && [ -n "$TOTAL_PACKAGE" ]; then
            PACKAGE_MB=$((TOTAL_PACKAGE / 1024 / 1024))
            INSTALL_MB=$((TOTAL_INSTALL / 1024 / 1024))
            echo "  • Package Size: ${PACKAGE_MB} MB"
            echo "  • Install Size: ${INSTALL_MB} MB"
            echo "  • Modules Found: ${MODULE_COUNT}"
            echo ""
            
            # Check if we have grouped by owner
            HAS_OWNERS=$(jq -r '.modulesByOwner != null' "$OUTPUT_FILE" 2>/dev/null)
            
            if [ "$HAS_OWNERS" = "true" ]; then
                echo "  Modules by Owner:"
                jq -r '.modulesByOwner | to_entries | sort_by(.key) | .[] | 
                    .key as $owner | 
                    (.value | to_entries | map(.value.binarySize) | add) as $total | 
                    "    • \($owner): \($total / 1024 / 1024 | floor) MB (\(.value | length) modules)"' \
                    "$OUTPUT_FILE" 2>/dev/null || true
                echo ""
            fi
            
            echo "  Top modules by size:"
            jq -r '.modules | to_entries | sort_by(.value.binarySize) | reverse | .[0:5] | .[] | 
                if .value.owner then 
                    "    - \(.key) (\(.value.owner)): \((.value.binarySize / 1024 / 1024 | floor)) MB"
                else 
                    "    - \(.key): \((.value.binarySize / 1024 / 1024 | floor)) MB"
                end' \
                "$OUTPUT_FILE" 2>/dev/null || true
        fi
    else
        echo "  (Install 'jq' for detailed summary: brew install jq)"
    fi
    
    echo ""
    info "View full report:"
    echo "  cat $OUTPUT_FILE | jq '.'"
    echo ""
    info "Unzipped files are in: $UNZIPPED_DIR"
    info "To clean up, run: rm -rf $UNZIPPED_DIR"
else
    error "Analysis failed with exit code: $EXIT_CODE"
    echo ""
    echo "Check the error messages above for details"
    echo "Partial output may be in: $OUTPUT_FILE"
fi

