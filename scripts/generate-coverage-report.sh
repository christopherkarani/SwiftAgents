#!/bin/bash
# Swarm Framework
# Test Coverage Report Generation Script
#
# This script generates comprehensive code coverage reports for Swarm
# Usage: ./scripts/generate-coverage-report.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COVERAGE_DIR=".build/coverage"
PROFDATA_PATH=".build/debug/codecov/default.profdata"
BUILD_DIR=".build/debug"
MIN_COVERAGE=70  # Minimum acceptable coverage percentage

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Swarm Code Coverage Report Generator         ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Clean previous coverage data
echo -e "${YELLOW}🧹 Cleaning previous coverage data...${NC}"
rm -rf "$COVERAGE_DIR"
mkdir -p "$COVERAGE_DIR"

# Run tests with coverage enabled
echo -e "${BLUE}🧪 Running tests with code coverage enabled...${NC}"
swift test --enable-code-coverage

# Check if profdata exists
if [ ! -f "$PROFDATA_PATH" ]; then
    echo -e "${RED}❌ Error: Coverage profdata not found at $PROFDATA_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Tests completed successfully${NC}"
echo ""

# Find test binaries
TEST_BINARIES=$(find "$BUILD_DIR" -name "*PackageTests.xctest" -o -name "*Tests.xctest" 2>/dev/null | grep -v "SwarmUITests" || true)

if [ -z "$TEST_BINARIES" ]; then
    echo -e "${RED}❌ Error: No test binaries found${NC}"
    exit 1
fi

# Get the main test binary (SwarmTests)
TEST_BINARY=$(echo "$TEST_BINARIES" | grep "SwarmPackageTests.xctest" | head -n 1)

if [ -z "$TEST_BINARY" ]; then
    TEST_BINARY=$(echo "$TEST_BINARIES" | head -n 1)
fi

# Determine the actual binary path inside the xctest bundle
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: binary is inside Contents/MacOS/
    BINARY_NAME=$(basename "$TEST_BINARY" .xctest)
    ACTUAL_BINARY="$TEST_BINARY/Contents/MacOS/$BINARY_NAME"
else
    # Linux: binary is the xctest file itself
    ACTUAL_BINARY="$TEST_BINARY"
fi

echo -e "${BLUE}📊 Generating coverage reports...${NC}"
echo -e "   Using binary: $ACTUAL_BINARY"
echo ""

# Generate text summary report
echo -e "${YELLOW}📄 Text Summary Report:${NC}"
xcrun llvm-cov report \
    "$ACTUAL_BINARY" \
    -instr-profile="$PROFDATA_PATH" \
    -ignore-filename-regex=".build|Tests" \
    -use-color

# Save text report to file
xcrun llvm-cov report \
    "$ACTUAL_BINARY" \
    -instr-profile="$PROFDATA_PATH" \
    -ignore-filename-regex=".build|Tests" \
    > "$COVERAGE_DIR/coverage-summary.txt"

echo ""

# Generate detailed HTML report
echo -e "${YELLOW}📊 Generating HTML report...${NC}"
xcrun llvm-cov show \
    "$ACTUAL_BINARY" \
    -instr-profile="$PROFDATA_PATH" \
    -ignore-filename-regex=".build|Tests" \
    -format=html \
    -output-dir="$COVERAGE_DIR/html" \
    -use-color

echo -e "${GREEN}✅ HTML report saved to: $COVERAGE_DIR/html/index.html${NC}"
echo ""

# Generate JSON report for CI integration
echo -e "${YELLOW}📋 Generating JSON report...${NC}"
xcrun llvm-cov export \
    "$ACTUAL_BINARY" \
    -instr-profile="$PROFDATA_PATH" \
    -ignore-filename-regex=".build|Tests" \
    -format=text \
    > "$COVERAGE_DIR/coverage.json"

echo -e "${GREEN}✅ JSON report saved to: $COVERAGE_DIR/coverage.json${NC}"
echo ""

# Generate lcov format for third-party tools (Codecov, Coveralls, etc.)
echo -e "${YELLOW}📋 Generating lcov report...${NC}"
xcrun llvm-cov export \
    "$ACTUAL_BINARY" \
    -instr-profile="$PROFDATA_PATH" \
    -ignore-filename-regex=".build|Tests" \
    -format=lcov \
    > "$COVERAGE_DIR/coverage.lcov"

echo -e "${GREEN}✅ lcov report saved to: $COVERAGE_DIR/coverage.lcov${NC}"
echo ""

# Extract overall coverage percentage
COVERAGE_PERCENT=$(xcrun llvm-cov report \
    "$ACTUAL_BINARY" \
    -instr-profile="$PROFDATA_PATH" \
    -ignore-filename-regex=".build|Tests" | \
    tail -n 1 | \
    awk '{print $NF}' | \
    sed 's/%//')

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Coverage Summary                       ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "   Overall Coverage: ${GREEN}${COVERAGE_PERCENT}%${NC}"
echo -e "   Minimum Required: ${YELLOW}${MIN_COVERAGE}%${NC}"
echo ""

# Check if coverage meets minimum threshold
if (( $(echo "$COVERAGE_PERCENT < $MIN_COVERAGE" | bc -l) )); then
    echo -e "${RED}❌ Coverage is below minimum threshold!${NC}"
    echo -e "   Current: ${COVERAGE_PERCENT}% | Required: ${MIN_COVERAGE}%"
    echo ""
    exit 1
else
    echo -e "${GREEN}✅ Coverage meets minimum threshold${NC}"
fi

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  Reports Generated                        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "   📄 Text Summary:  $COVERAGE_DIR/coverage-summary.txt"
echo -e "   📊 HTML Report:   $COVERAGE_DIR/html/index.html"
echo -e "   📋 JSON Report:   $COVERAGE_DIR/coverage.json"
echo -e "   📋 lcov Report:   $COVERAGE_DIR/coverage.lcov"
echo ""
echo -e "${GREEN}✅ Coverage report generation completed successfully!${NC}"
echo ""
