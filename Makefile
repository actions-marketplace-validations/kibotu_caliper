.PHONY: build install clean release help format analyze example

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
	@echo "✅ Installation complete! Run 'caliper --help' to get started."

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build

# Show help
help: build
	.build/debug/Caliper --help

# Format code (requires swift-format)
format:
	swift-format --in-place --recursive Sources/

# Full analysis with automatic HTML generation
analyze: release
	@if [ -z "$(IPA_PATH)" ]; then \
		echo "❌ Error: IPA_PATH not set"; \
		echo ""; \
		echo "Usage:"; \
		echo "  make analyze IPA_PATH=path/to/app.ipa [OPTIONS]"; \
		echo ""; \
		echo "Options:"; \
		echo "  LINK_MAP_PATH=path/to/LinkMap.txt    - LinkMap for accurate binary sizes"; \
		echo "  OWNERSHIP_FILE=module-ownership.yml  - Module ownership tracking"; \
		echo "  FILTER_OWNER=team-name               - Filter by specific owner"; \
		echo "  OUTPUT=report.json                   - Output file (default: report.json)"; \
		echo ""; \
		echo "Example:"; \
		echo "  make analyze IPA_PATH=MyApp.ipa LINK_MAP_PATH=LinkMap.txt"; \
		exit 1; \
	fi
	@OUTPUT=$${OUTPUT:-report.json}; \
	CMD=".build/release/Caliper --ipa-path $(IPA_PATH) --output $$OUTPUT"; \
	if [ -n "$(LINK_MAP_PATH)" ]; then CMD="$$CMD --link-map-path $(LINK_MAP_PATH)"; fi; \
	if [ -n "$(OWNERSHIP_FILE)" ]; then CMD="$$CMD --ownership-file $(OWNERSHIP_FILE) --group-by-owner"; fi; \
	if [ -n "$(FILTER_OWNER)" ]; then CMD="$$CMD --filter-owner $(FILTER_OWNER)"; fi; \
	echo "🚀 Running: $$CMD"; \
	echo ""; \
	eval $$CMD; \
	echo ""; \
	HTML_FILE=$$(echo $$OUTPUT | sed 's/\.[^.]*$$/.html/'); \
	if [ -f "$$HTML_FILE" ]; then \
		echo "✅ Analysis complete!"; \
		echo "   📄 JSON report: $$OUTPUT"; \
		echo "   🌐 HTML report: $$HTML_FILE"; \
		echo ""; \
		echo "💡 To view the HTML report, run: open $$HTML_FILE"; \
	fi

# Quick example run (outputs to stdout, no HTML)
example: release
	@if [ -z "$(IPA_PATH)" ]; then \
		echo "❌ Error: IPA_PATH not set"; \
		echo "Usage: make example IPA_PATH=path/to/app.ipa"; \
		exit 1; \
	fi
	@CMD=".build/release/Caliper --ipa-path $(IPA_PATH)"; \
	if [ -n "$(LINK_MAP_PATH)" ]; then CMD="$$CMD --link-map-path $(LINK_MAP_PATH)"; fi; \
	if [ -n "$(OWNERSHIP_FILE)" ]; then CMD="$$CMD --ownership-file $(OWNERSHIP_FILE) --group-by-owner"; fi; \
	if [ -n "$(FILTER_OWNER)" ]; then CMD="$$CMD --filter-owner $(FILTER_OWNER)"; fi; \
	echo "🚀 Running: $$CMD"; \
	echo ""; \
	eval $$CMD

