# Caliper Sample App 🎭

A pragmatic iOS sample application demonstrating [Orchard](https://github.com/kibotu/Orchard) logging integration with link map generation for size analysis.

## Features

- ✨ **Orchard Logging**: Beautiful structured logging with tags, icons, and metadata
- 🗺️ **Link Map Generation**: Automatic link map creation for binary size analysis
- 🎭 **Comedy Central**: Logs programmer jokes on launch (because why not?)
- 📱 **Simple UI**: Clean UIKit implementation with joke display
- 🔨 **No Code Signing**: Build and create IPA without certificates

## Quick Start

### Prerequisites

- Xcode 15.0 or later
- iOS 15.0 or later
- Swift 5.9+
- Command line tools installed: `xcode-select --install`

### Build & Run

#### Option 1: Build Script (Recommended)

```bash
cd Sample
chmod +x build.sh
./build.sh
```

```sh
../.build/release/caliper \
  --ipa-path build/CaliperSampleApp.ipa  \
  --link-map-path build/CaliperSampleApp-LinkMap.txt \
  --package-resolved-path CaliperSampleApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved 
```


This will:
- ✅ Build the app without code signing
- ✅ Generate link map file
- ✅ Create IPA package
- ✅ Display build artifacts

**Output:**
```
build/
├── CaliperSampleApp.ipa              # Ready to install
└── CaliperSampleApp-LinkMap.txt      # For size analysis
```

#### Option 2: Manual Build

```bash
# Clean build
xcodebuild clean build \
    -project CaliperSampleApp.xcodeproj \
    -scheme CaliperSampleApp \
    -configuration Release \
    -sdk iphoneos \
    -derivedDataPath build/DerivedData \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    DEVELOPMENT_TEAM=""

# Create IPA
mkdir -p build/Payload
cp -r build/DerivedData/Build/Products/Release-iphoneos/CaliperSampleApp.app build/Payload/
cd build && zip -r CaliperSampleApp.ipa Payload && cd ..
```

#### Option 3: Xcode

1. Open `CaliperSampleApp.xcodeproj`
2. Wait for Swift Package Manager to resolve dependencies
3. Select any iOS Simulator
4. Press `Cmd + R` to build and run

## Project Structure

```
Sample/
├── CaliperSampleApp.xcodeproj/      # Xcode project
├── Sources/
│   ├── AppDelegate.swift             # Orchard setup + joke logging
│   ├── ViewController.swift          # Simple UI with joke display
│   └── Info.plist                    # App configuration
├── Package.swift                     # SPM configuration (Orchard dependency)
├── build.sh                          # Automated build script
└── README.md                         # This file
```

## Orchard Configuration

The app demonstrates best practices for Orchard logging:

### 1. Logger Setup (AppDelegate)

```swift
private func setupLogger() {
    let logger = ConsoleLogger { config in
        config.minimumLogLevel = .verbose
        config.showTimestamp = true
        config.showFileLocation = true
        config.showFunctionName = true
        config.showLineNumber = true
        config.moduleNameMapper = { moduleName in
            return moduleName.components(separatedBy: "/").last ?? moduleName
        }
    }
    
    Orchard.loggers.append(logger)
    Orchard.tag("Setup").icon("🌳").i("Orchard logger configured successfully")
}
```

### 2. Structured Logging with Metadata

```swift
Orchard.tag("Comedy").icon("🎭").i(
    "Daily Joke",
    [
        "joke": randomJoke,
        "timestamp": Date().description,
        "source": "AppDelegate"
    ]
)
```

**Console Output:**
```
🎭 13:54:48.403: [Comedy/AppDelegate.logJoke():42] Daily Joke {"joke":"Why do programmers prefer dark mode? Because light attracts bugs! 🐛","timestamp":"2025-11-11 13:54:48 +0000","source":"AppDelegate"}
```

### 3. All Log Levels

```swift
Orchard.v("Verbose: Detailed debug information")    // 🔬
Orchard.d("Debug: Development information")          // 🔍
Orchard.i("Info: General information")               // ℹ️
Orchard.w("Warning: Something needs attention")      // ⚠️
Orchard.e("Error: Something went wrong")             // ❌
Orchard.f("Fatal: Critical error!")                  // ⚡️
```

## Link Map Generation

The project is configured to generate link maps for binary size analysis:

### Configuration

In `project.pbxproj`, the following build setting is configured:

```
OTHER_LDFLAGS = "-Wl,-map,$(TARGET_TEMP_DIR)/$(PRODUCT_NAME)-LinkMap.txt"
```

### Usage with Caliper

Once you have the link map and IPA, analyze them with Caliper:

```bash
# Build the sample app
cd Sample
./build.sh

# Analyze with Caliper (from repo root)
cd ..
swift run caliper analyze \
    --ipa Sample/build/CaliperSampleApp.ipa \
    --linkmap Sample/build/CaliperSampleApp-LinkMap.txt \
    --output caliper-report.json
```

## Sample Output

When you run the app, you'll see logs like:

```
🌳 13:54:48.402: [Setup/AppDelegate.setupLogger():31] Orchard logger configured successfully
🎭 13:54:48.403: [Comedy/AppDelegate.logJoke():45] Daily Joke {"joke":"Why do Java developers wear glasses? Because they can't C#! 👓","timestamp":"2025-11-11 13:54:48 +0000","source":"AppDelegate"}
😂 13:54:48.403: [Comedy/AppDelegate.logJoke():47] Why do Java developers wear glasses? Because they can't C#! 👓
📱 13:54:48.404: [UI/ViewController.viewDidLoad():29] ViewController loaded
🎭 13:54:48.405: [Comedy/ViewController.refreshJoke():67] New joke displayed {"joke":"How many programmers does it take to change a light bulb? None, that's a hardware problem! 💡"}
```

## Dependencies

- [Orchard](https://github.com/kibotu/Orchard) - Beautiful iOS logging framework

## Integration with Caliper

This sample app is designed to work seamlessly with the Caliper binary size analyzer:

1. **Build the app** → Generates IPA + Link Map
2. **Run Caliper** → Analyzes binary size breakdown
3. **View Report** → Understand size contributions

Perfect for:
- 📊 Size regression testing
- 🔍 Identifying bloat sources  
- 📈 Tracking size over time
- 🎯 Optimizing binary size

## Troubleshooting

### Build fails with "xcodebuild: command not found"

Install Xcode command line tools:
```bash
xcode-select --install
```

### SPM dependency resolution fails

```bash
# Reset package cache
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf .build

# Re-open project in Xcode
open CaliperSampleApp.xcodeproj
```

### Link map not generated

Verify build settings:
```bash
xcodebuild -project CaliperSampleApp.xcodeproj \
    -target CaliperSampleApp \
    -showBuildSettings | grep OTHER_LDFLAGS
```

Should output:
```
OTHER_LDFLAGS = -Wl,-map,$(TARGET_TEMP_DIR)/$(PRODUCT_NAME)-LinkMap.txt
```

## License

Apache 2.0 - See [LICENSE](../LICENSE) for details.

## Contributing

Issues and pull requests welcome! This is a sample app to demonstrate Caliper usage.

---

**Made with ❤️ for iOS developers who care about binary size**

For more information about Orchard logging, visit: [github.com/kibotu/Orchard](https://github.com/kibotu/Orchard)

