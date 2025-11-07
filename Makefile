.PHONY: build install clean release test

# Build the debug version
build:
	swift build

# Build the release version
release:
	swift build -c release

# Install to /usr/local/bin
install: release
	@echo "Installing Caliper to /usr/local/bin..."
	@cp .build/release/Caliper /usr/local/bin/caliper
	@echo "Installation complete! Run 'caliper --help' to get started."

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build

# Run help
help: build
	.build/debug/Caliper --help

# Format code (requires swift-format)
format:
	swift-format --in-place --recursive Sources/

# Test with example (requires IPA file)
test-example:
	@echo "To test, run:"
	@echo "make run-example IPA_PATH=path/to/app.ipa UNZIPPED_PATH=path/to/unzipped"

# Run example with provided paths
run-example:
	@if [ -z "$(IPA_PATH)" ]; then echo "Error: IPA_PATH not set"; exit 1; fi
	@if [ -z "$(UNZIPPED_PATH)" ]; then echo "Error: UNZIPPED_PATH not set"; exit 1; fi
	.build/debug/Caliper \
		--ipa-path $(IPA_PATH) \
		--unzipped-path $(UNZIPPED_PATH) \
		--pretty-print

