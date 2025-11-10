# Caliper [![Build](https://github.com/kibotu/caliper/actions/workflows/build.yml/badge.svg)](https://github.com/kibotu/caliper/actions/workflows/build.yml)

A Swift command-line tool for measuring binary and bundle sizes in iOS IPA files.

## Quick Start

```bash
# Build
swift build -c release

# Analyze an IPA (generates report.json and report.html)
.build/release/Caliper --ipa-path MyApp.ipa

# With LinkMap for accurate binary sizes
.build/release/Caliper \
  --ipa-path MyApp.ipa \
  --link-map-path MyApp-LinkMap.txt

# With module ownership tracking
.build/release/Caliper \
  --ipa-path MyApp.ipa \
  --link-map-path MyApp-LinkMap.txt \
  --ownership-file module-ownership.yml

# With Swift package version information
.build/release/Caliper \
  --ipa-path MyApp.ipa \
  --link-map-path MyApp-LinkMap.txt \
  --ownership-file module-ownership.yml \
  --package-resolved-path Package.resolved

# With package name mapping (for namespaced packages)
.build/release/Caliper \
  --ipa-path MyApp.ipa \
  --link-map-path MyApp-LinkMap.txt \
  --ownership-file module-ownership.yml \
  --package-resolved-path Package.resolved \
  --package-mapping-file package-name-mapping.yml
```

Reports are always saved to `report.json` and `report.html` in the current directory.

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
# Analyze an IPA (creates report.json and report.html)
.build/release/Caliper --ipa-path MyApp.ipa
```

### With LinkMap

LinkMap files provide accurate binary size measurements:

```bash
.build/release/Caliper \
  --ipa-path MyApp.ipa \
  --link-map-path MyApp-LinkMap.txt
```

### Module Ownership

Track module ownership with a YAML file:

```yaml
- identifier: "MyFeature*"
  owner: "team-alpha"
  module: "MyFeature"
```

```bash
# Analyze with ownership tracking (modules grouped by owner in output)
.build/release/Caliper \
  --ipa-path MyApp.ipa \
  --link-map-path MyApp-LinkMap.txt \
  --ownership-file module-ownership.yml
```

### Swift Package Versions

Include Swift package version information from `Package.resolved`:

```bash
# Analyze with package version tracking
.build/release/Caliper \
  --ipa-path MyApp.ipa \
  --link-map-path MyApp-LinkMap.txt \
  --package-resolved-path Package.resolved
```

This will add version information to each module in the output, making it easier to track which versions of dependencies are included in your build.

### Package Name Mapping

For handling namespaced packages in `Package.resolved` (e.g., in-house packages like `ext.adjust_signature_sdk`), you can provide a mapping file:

```yaml
# package-name-mapping.yml
- moduleName: adjust_signature_sdk
  packageIdentity: ext.adjust_signature_sdk

- moduleName: AdjustSignatureSDK
  packageIdentity: ext.adjust_signature_sdk
```

```bash
# Analyze with package name mapping
.build/release/Caliper \
  --ipa-path MyApp.ipa \
  --link-map-path MyApp-LinkMap.txt \
  --package-resolved-path Package.resolved \
  --package-mapping-file package-name-mapping.yml
```

This ensures that modules are correctly matched to their namespaced package identities when resolving version information.

## Command Line Options

```
USAGE: caliper --ipa-path <ipa-path> [--link-map-path <link-map-path>] [--ownership-file <ownership-file>] [--package-resolved-path <package-resolved-path>] [--package-mapping-file <package-mapping-file>]

OPTIONS:
  --ipa-path <ipa-path>   Path to the IPA file
  --link-map-path <link-map-path>
                          Optional path to LinkMap file for accurate binary sizes
  --ownership-file <ownership-file>
                          Optional YAML file containing module ownership configuration
  --package-resolved-path <package-resolved-path>
                          Optional path to Package.resolved file for Swift package version information
  --package-mapping-file <package-mapping-file>
                          Optional YAML file containing package name mappings (for handling namespaced packages)
```

## HTML Reports

HTML reports are automatically generated as `report.html` alongside the JSON output.

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
      "owner": "team-alpha",
      "version": "1.2.3",
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
- `name` - Module/framework name
- `owner` - Team/owner (if ownership file provided)
- `version` - Package version (if Package.resolved provided)
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
                --link-map-path build/LinkMap.txt
        """
        archiveArtifacts artifacts: 'report.json,report.html'
        publishHTML([
            reportDir: '.',
            reportFiles: 'report.html',
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
      --link-map-path build/LinkMap.txt

- name: Upload Reports
  uses: actions/upload-artifact@v3
  with:
    name: app-size-reports
    path: |
      report.json
      report.html
```

## Features

- Binary, asset, and resource size measurements
- Module/package categorization
- LinkMap parsing for accurate binary sizes
- Compressed (IPA) and uncompressed (install) size calculations
- Asset catalog (.car files) analysis
- Interactive HTML reports
- Module ownership tracking
- Swift package version tracking from Package.resolved
- Package name mapping support for namespaced packages
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
