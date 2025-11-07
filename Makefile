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
	@echo "  make run-example IPA_PATH=path/to/app.ipa"
	@echo ""
	@echo "Optional parameters:"
	@echo "  LINK_MAP_PATH=path/to/LinkMap.txt"
	@echo "  OWNERSHIP_FILE=module-ownership.yml"
	@echo "  FILTER_OWNER=team-name"
	@echo "  OUTPUT=report.json"

# Run example with provided paths (simplified - auto-unzip)
run-example: release
	@if [ -z "$(IPA_PATH)" ]; then \
		echo "Error: IPA_PATH not set"; \
		echo "Usage: make run-example IPA_PATH=path/to/app.ipa"; \
		exit 1; \
	fi
	@CMD=".build/release/Caliper --ipa-path $(IPA_PATH)"; \
	if [ -n "$(LINK_MAP_PATH)" ]; then CMD="$$CMD --link-map-path $(LINK_MAP_PATH)"; fi; \
	if [ -n "$(OWNERSHIP_FILE)" ]; then CMD="$$CMD --ownership-file $(OWNERSHIP_FILE) --group-by-owner"; fi; \
	if [ -n "$(FILTER_OWNER)" ]; then CMD="$$CMD --filter-owner $(FILTER_OWNER)"; fi; \
	if [ -n "$(OUTPUT)" ]; then CMD="$$CMD --output $(OUTPUT)"; fi; \
	echo "Running: $$CMD"; \
	echo ""; \
	eval $$CMD

