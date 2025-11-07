# Caliper

A Swift command-line tool for measuring binary and bundle sizes of Swift packages in iOS IPA files.

## Quick Start

```bash
# Build the tool
swift build -c release

# Analyze an IPA (automatic unzipping and cleanup)
.build/release/Caliper --ipa-path MyApp.ipa

# With LinkMap for accurate binary sizes
.build/release/Caliper \
  --ipa-path MyApp.ipa \
  --link-map-path MyApp-LinkMap.txt

# Save output to file
.build/release/Caliper --ipa-path MyApp.ipa --output report.json
```

## Features

- 📊 Measures binary sizes, image assets, resources, and more
- 🎯 Categorizes files by module/package
- 🔍 Parses LinkMap files for accurate binary size measurements
- 📦 Calculates both compressed (IPA) and uncompressed (install) sizes
- 🎨 Analyzes asset catalogs (.car files) with detailed breakdowns
- 📄 Outputs structured JSON for easy integration

## Installation

### Quick Start

Build the tool:

```bash
swift build -c release
```

The compiled binary will be at `.build/release/Caliper`.

### System-wide Installation (Optional)

Install to `/usr/local/bin` for easy access:

```bash
make install
```

Then use it from anywhere as `caliper`.

## Usage

### Simple Usage (Recommended)

The simplest way to use Caliper - it handles unzipping automatically:

```bash
.build/release/Caliper --ipa-path path/to/YourApp.ipa
```

This will:
- ✅ Automatically unzip the IPA to a temporary directory
- ✅ Analyze the contents
- ✅ Clean up the temporary directory when done
- ✅ Output formatted JSON to stdout

### Use Existing Unzipped Directory

If you've already unzipped the IPA:

```bash
.build/release/Caliper \
  --ipa-path path/to/YourApp.ipa \
  --unzipped-path path/to/unzipped/app
```

### With LinkMap for Accurate Binary Sizes

```bash
.build/release/Caliper \
  --ipa-path path/to/YourApp.ipa \
  --link-map-path path/to/YourApp-LinkMap-normal-arm64.txt
```

### With Module Ownership Tracking

Create a YAML ownership file (see `module-ownership.yml` for example):

```yaml
- identifier: "MyFeature*"
  owner: "team-alpha"
  module: "MyFeature"
- identifier: "CoreFeature*"
  owner: "team-core"
  module: "CoreFeature"
```

Then run with ownership tracking:

```bash
.build/release/Caliper \
  --ipa-path path/to/YourApp.ipa \
  --ownership-file module-ownership.yml \
  --group-by-owner
```

### Filter by Owner

To see only modules owned by a specific team:

```bash
.build/release/Caliper \
  --ipa-path path/to/YourApp.ipa \
  --ownership-file module-ownership.yml \
  --filter-owner team-alpha
```

### Save Output to File

```bash
.build/release/Caliper \
  --ipa-path path/to/YourApp.ipa \
  --output app-size-report.json
```

Or use the short form:

```bash
.build/release/Caliper --ipa-path path/to/YourApp.ipa -o report.json
```

## Output Format

The tool outputs JSON with the following structure:

```json
{
  "modules": {
    "C24Core": {
      "name": "C24Core",
      "binarySize": 1234567,
      "imageSize": 234567,
      "imageFileSize": 345678,
      "proguard": 2345678,
      "resources": {
        "png": {
          "size": 123456,
          "count": 42
        },
        "pdf": {
          "size": 67890,
          "count": 15
        }
      },
      "top": {
        "path/to/large/file.png": 12345,
        "path/to/another/large/file.pdf": 11234
      }
    }
  },
  "totalPackageSize": 12345678,
  "totalInstallSize": 23456789
}
```

### Field Descriptions

- `binarySize`: Size of the compiled binary code (bytes)
- `imageSize`: Total compressed size of image assets (bytes)
- `imageFileSize`: Total uncompressed size of image assets (bytes)
- `proguard`: Total uncompressed size of all module files (bytes)
- `resources`: Breakdown of resource files by type
- `top`: Top 30 largest files in the module
- `totalPackageSize`: Total IPA file size (bytes)
- `totalInstallSize`: Total installed app size (bytes)

## Integration with CI/CD

### Jenkins Pipeline Example

Simplified Jenkins pipeline stage (no manual unzipping needed):

```groovy
stage('App Size Analysis') {
    steps {
        script {
            // Build Caliper if not already built
            sh 'cd caliper && swift build -c release'
            
            // Run Caliper (it handles unzipping automatically)
            sh """
                caliper/.build/release/Caliper \
                    --ipa-path build/app/YourApp.ipa \
                    --link-map-path build/derived_data/.../LinkMap.txt \
                    --ownership-file caliper/module-ownership.yml \
                    --group-by-owner \
                    --output app-size-report.json
            """
            
            // Archive the report
            archiveArtifacts artifacts: 'app-size-report.json'
            
            // Parse and use the JSON output
            def json = readJSON file: 'app-size-report.json'
            echo "📦 Total package size: ${json.totalPackageSize / 1024 / 1024} MB"
            echo "💾 Total install size: ${json.totalInstallSize / 1024 / 1024} MB"
            
            // Example: Fail build if size exceeds threshold
            def maxSizeMB = 100
            def actualSizeMB = json.totalPackageSize / 1024 / 1024
            if (actualSizeMB > maxSizeMB) {
                error("App size ${actualSizeMB} MB exceeds threshold of ${maxSizeMB} MB")
            }
        }
    }
}
```

### GitHub Actions Example

```yaml
- name: Analyze App Size
  run: |
    swift build -c release
    .build/release/Caliper \
      --ipa-path build/YourApp.ipa \
      --link-map-path build/LinkMap.txt \
      --output app-size-report.json

- name: Upload Size Report
  uses: actions/upload-artifact@v3
  with:
    name: app-size-report
    path: app-size-report.json
```

## Comparison with spotify/ruler

Caliper is inspired by [Spotify's Ruler](https://github.com/spotify/ruler) but tailored for iOS-specific needs:

- ✅ Native Swift implementation (no Ruby dependencies)
- ✅ iOS-specific asset catalog parsing
- ✅ LinkMap integration for accurate binary measurements
- ✅ Designed for CI/CD integration
- ✅ Module-level size breakdown

## Requirements

- macOS 13.0+
- Xcode command-line tools (for `xcrun assetutil`)
- Swift 5.9+

## Migration from Bash Script

> ⚠️ **Note**: The `analyze-ipa.sh` bash script is now deprecated. Use the Swift tool directly instead.

**Old way (deprecated):**
```bash
./analyze-ipa.sh MyApp.ipa path/to/LinkMap.txt module-ownership.yml
```

**New way (recommended):**
```bash
swift build -c release
.build/release/Caliper \
  --ipa-path MyApp.ipa \
  --link-map-path path/to/LinkMap.txt \
  --ownership-file module-ownership.yml \
  --group-by-owner \
  --output report.json
```

Benefits of the new approach:
- ✅ No dependency on bash scripts
- ✅ Automatic unzipping and cleanup (always)
- ✅ Clean command-line interface
- ✅ Built-in file output support
- ✅ Pretty-printed JSON by default
- ✅ Better error handling
- ✅ Easier to maintain and extend

## License

Internal use only.

