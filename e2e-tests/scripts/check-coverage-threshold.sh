#!/bin/bash
# Check that an lcov tracefile meets a minimum line coverage threshold.
#
# Usage: check-coverage-threshold.sh <coverage.info> <threshold_percent>
#
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

COVERAGE_INFO="${1:?Usage: check-coverage-threshold.sh <coverage.info> <threshold_percent>}"
THRESHOLD="${2:?Usage: check-coverage-threshold.sh <coverage.info> <threshold_percent>}"

# Extract line coverage percentage from lcov --summary output
SUMMARY=$(lcov --summary "$COVERAGE_INFO" 2>&1)
COVERAGE=$(echo "$SUMMARY" | grep 'lines' | sed 's/.*: *\([0-9.]*\)%.*/\1/')

if [ -z "$COVERAGE" ]; then
    echo "ERROR: Could not parse line coverage from lcov summary"
    echo "$SUMMARY"
    exit 1
fi

echo "Line coverage: ${COVERAGE}%  (threshold: ${THRESHOLD}%)"

# Floating-point comparison via awk (handles decimals like 55.3)
if awk "BEGIN{exit($COVERAGE >= $THRESHOLD ? 0 : 1)}"; then
    echo "OK: E2E line coverage meets threshold"
else
    echo "FAIL: E2E line coverage ${COVERAGE}% is below ${THRESHOLD}% threshold"
    exit 1
fi
