# Simple Makefile for common tasks (non-invasive)
# - Uses Swift Package commands when available
# - Can open Xcode project/workspace if present, or fall back to `xed .`
# - Does not modify source files

SWIFT := swift
PKG_NAME := ntfy-macos

SWIFT_BUILD_FLAGS ?=
SWIFT_RUN_FLAGS ?=
SWIFT_TEST_FLAGS ?=

.PHONY: help build clean run test open-xcode open-vscode

help:
	@echo "Makefile targets:"
	@echo "  make build         # build via Swift Package Manager"
	@echo "  make run           # run the executable (swift run)"
	@echo "  make test          # run the test suite (swift test)"
	@echo "  make clean         # swift package clean"
	@echo "  make open-xcode    # open Xcode workspace/project if present, else open package with xed"
	@echo "  make open-vscode   # open repository in VS Code (uses 'code' if available)"

# Build using SwiftPM
build:
	@echo "Building package..."
	@$(SWIFT) build $(SWIFT_BUILD_FLAGS)

# Clean build artifacts
clean:
	@echo "Cleaning..."
	@$(SWIFT) package clean

# Run the executable via SwiftPM
run:
	@echo "Running $(PKG_NAME)..."
	@$(SWIFT) run $(SWIFT_RUN_FLAGS) $(PKG_NAME)

# Run tests via SwiftPM
test:
	@echo "Running tests..."
	@$(SWIFT) test $(SWIFT_TEST_FLAGS)

# Open Xcode workspace/project if present, otherwise open package with xed (if available)
open-xcode:
	@echo "Locating Xcode workspace/project..."
	@XWORKSPACE=$$(ls *.xcworkspace 2>/dev/null | head -n1 || true); \
	if [ -n "$$XWORKSPACE" ]; then \
		echo "Opening workspace: $$XWORKSPACE"; open "$$XWORKSPACE"; \
	else \
		XPROJ=$$(ls *.xcodeproj 2>/dev/null | head -n1 || true); \
		if [ -n "$$XPROJ" ]; then \
			echo "Opening project: $$XPROJ"; open "$$XPROJ"; \
		else \
			if command -v xed >/dev/null 2>&1; then \
				echo "No Xcode project found — opening package in Xcode via xed ."; \
				xed .; \
			else \
				echo "No Xcode project/workspace found and 'xed' is not available."; \
				echo "Open the Package.swift in Xcode manually or generate an Xcode project."; \
				exit 1; \
			fi; \
		fi; \
	fi

# Open repository in VS Code (prefers 'code' CLI if available, falls back to opening the app)
open-vscode:
	@if command -v code >/dev/null 2>&1; then \
		echo "Opening in VS Code (code .)"; \
		code .; \
	else \
		echo "'code' CLI not found — attempting to open VS Code application"; \
		open -a "Visual Studio Code" . || (echo "Failed to open VS Code. Install 'code' CLI from the Command Palette in VS Code." && exit 1); \
	fi
