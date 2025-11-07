# Caliper

A Swift command-line tool for measuring binary and bundle sizes of Swift packages in iOS IPA files.

## Features

- 📊 Measures binary sizes, image assets, resources, and more
- 🎯 Categorizes files by module/package
- 🔍 Parses LinkMap files for accurate binary size measurements
- 📦 Calculates both compressed (IPA) and uncompressed (install) sizes
- 🎨 Analyzes asset catalogs (.car files) with detailed breakdowns
- 📄 Outputs structured JSON for easy integration

## Installation

Build the tool:

```bash
swift build -c release
```

The compiled binary will be at `.build/release/Caliper`.

## Usage

### Basic Usage

```bash
caliper \
  --ipa-path path/to/YourApp.ipa \
  --unzipped-path path/to/unzipped/app \
  --pretty-print
```

### With LinkMap for Accurate Binary Sizes

```bash
caliper \
  --ipa-path path/to/YourApp.ipa \
  --unzipped-path path/to/unzipped/app \
  --link-map-path path/to/YourApp-LinkMap-normal-arm64.txt \
  --pretty-print
```

### With Custom Module Mapping

Create a JSON file with your module mappings:

```json
{
  "MyFramework": "MyModule",
  "AnotherFramework": "AnotherModule"
}
```

Then run:

```bash
caliper \
  --ipa-path path/to/YourApp.ipa \
  --unzipped-path path/to/unzipped/app \
  --module-mapping-path module-mappings.json \
  --pretty-print
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

## Default Module Mappings

The tool includes default mappings for:
- `ProfisPartnerCore` → `C24Core`
- `ProfisPartnerMover` → `C24Mover`
- `ProfisPartnerCraftsmen` → `C24Craftsmen`
- `ProfisPartnerEvents` → `C24Events`
- `C24ProfisNativeMessenger` → `C24ProfisNativeMessenger`

## Integration with Jenkins

Example Jenkins pipeline stage:

```groovy
stage('App Size Analysis') {
    steps {
        script {
            // Unzip IPA
            unzip zipFile: "build/app/YourApp.ipa", dir: "build/app/YourApp"
            
            // Run Caliper
            def report = sh(
                returnStdout: true,
                script: """
                    caliper/caliper \
                        --ipa-path build/app/YourApp.ipa \
                        --unzipped-path build/app/YourApp \
                        --link-map-path build/derived_data/.../LinkMap.txt \
                        --pretty-print
                """
            ).trim()
            
            echo report
            
            // Parse and use the JSON output as needed
            def json = readJSON text: report
            echo "Total package size: ${json.totalPackageSize}"
        }
    }
}
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

## License

Internal use only.

