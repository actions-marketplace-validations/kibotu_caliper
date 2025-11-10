# Caliper

A Swift command-line tool for measuring binary and bundle sizes in iOS IPA files.

## Quick Start

```bash
# Build
swift build -c release

# Analyze an IPA
.build/release/Caliper --ipa-path MyApp.ipa --output report.json

# With LinkMap for accurate binary sizes
.build/release/Caliper \
  --ipa-path MyApp.ipa \
  --link-map-path MyApp-LinkMap.txt \
  --output report.json

# Using Make
make analyze IPA_PATH=MyApp.ipa OUTPUT=report.json
```

HTML reports are automatically generated alongside JSON output.

## Installation

```bash
# Build locally
swift build -c release

# Install system-wide (optional)
make install
```

## Usage

### Basic Analysis

```bash
# Output to stdout
.build/release/Caliper --ipa-path MyApp.ipa

# Save to file (creates report.json and report.html)
.build/release/Caliper --ipa-path MyApp.ipa -o report.json
```

### With LinkMap

LinkMap files provide accurate binary size measurements:

```bash
.build/release/Caliper \
  --ipa-path MyApp.ipa \
  --link-map-path MyApp-LinkMap.txt \
  --output report.json
```

### Module Ownership

Track module ownership with a YAML file:

```yaml
- identifier: "MyFeature*"
  owner: "team-alpha"
  module: "MyFeature"
```

```bash
# Group by owner
.build/release/Caliper \
  --ipa-path MyApp.ipa \
  --ownership-file module-ownership.yml \
  --group-by-owner \
  --output report.json

# Filter by specific owner
.build/release/Caliper \
  --ipa-path MyApp.ipa \
  --ownership-file module-ownership.yml \
  --filter-owner team-alpha \
  --output report.json
```

### Using Makefile

```bash
# Full analysis
make analyze IPA_PATH=MyApp.ipa LINK_MAP_PATH=LinkMap.txt OUTPUT=report.json

# Quick test (stdout only)
make example IPA_PATH=MyApp.ipa
```

## HTML Reports

HTML reports are automatically generated when you specify `--output`. The HTML file uses the same name as your JSON file with `.html` extension.

Features:
- Search and filter modules
- Sort by size, binary size, or name
- Expandable module details
- Resource breakdowns by file type
- Top 10 largest files per module

## Output Format

JSON structure:

```json
{
  "modules": {
    "ModuleName": {
      "name": "ModuleName",
      "binarySize": 1234567,
      "imageSize": 234567,
      "imageFileSize": 345678,
      "proguard": 2345678,
      "resources": {
        "png": { "size": 123456, "count": 42 }
      },
      "top": {
        "path/to/file.png": 12345
      }
    }
  },
  "totalPackageSize": 12345678,
  "totalInstallSize": 23456789
}
```

Fields:
- `binarySize` - Compiled binary code size (bytes)
- `imageSize` - Compressed image assets (bytes)
- `imageFileSize` - Uncompressed image assets (bytes)
- `proguard` - Total uncompressed module size (bytes)
- `resources` - Resource files grouped by type
- `top` - Top 30 largest files
- `totalPackageSize` - IPA file size (bytes)
- `totalInstallSize` - Installed app size (bytes)

## CI/CD Integration

### Jenkins

```groovy
stage('App Size Analysis') {
    steps {
        sh 'cd caliper && swift build -c release'
        sh """
            caliper/.build/release/Caliper \
                --ipa-path build/app/YourApp.ipa \
                --link-map-path build/LinkMap.txt \
                --output app-size-report.json
        """
        archiveArtifacts artifacts: 'app-size-report.json,app-size-report.html'
        publishHTML([
            reportDir: '.',
            reportFiles: 'app-size-report.html',
            reportName: 'App Size Report'
        ])
    }
}
```

### GitHub Actions

```yaml
- name: Analyze App Size
  run: |
    swift build -c release
    .build/release/Caliper \
      --ipa-path build/YourApp.ipa \
      --link-map-path build/LinkMap.txt \
      --output app-size-report.json

- name: Upload Reports
  uses: actions/upload-artifact@v3
  with:
    name: app-size-reports
    path: |
      app-size-report.json
      app-size-report.html
```

## Features

- Binary, asset, and resource size measurements
- Module/package categorization
- LinkMap parsing for accurate binary sizes
- Compressed (IPA) and uncompressed (install) size calculations
- Asset catalog (.car files) analysis
- Interactive HTML reports
- Module ownership tracking
- Automatic IPA handling (unzip/cleanup)
- Clean, modular architecture for easy maintenance and extension

## Architecture

Caliper follows a clean, modular architecture with clear separation of concerns:

```
Sources/Caliper/
├── Models/         # Data structures
├── Services/       # Business logic
├── Parsers/        # File parsing
├── Reporters/      # Output generation
├── Utilities/      # Helper functions
└── Errors/         # Error types
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed documentation on the project structure, design patterns, and extension points.

## Requirements

- macOS 13.0+
- Xcode command-line tools
- Swift 5.9+

## Inspiration

Inspired by [Spotify's Ruler](https://github.com/spotify/ruler), adapted for iOS with native Swift implementation and iOS-specific features.

## License

Internal use only.
