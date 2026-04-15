#!/bin/bash
# Validates that the TCG coverage plugin's address range covers the
# full SP ELF .text section.  Uses the text_begin / text_end symbols
# emitted by the linker script (image.ld).
#
# Usage: validate-address-window.sh <SP_ELF> [range_lo] [range_hi]
#
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

ELF="${1:?Usage: validate-address-window.sh <SP_ELF> [range_lo] [range_hi]}"
RANGE_LO="${2:-0x20802000}"
RANGE_HI="${3:-0x21002000}"

# Extract text_begin and text_end linker symbols from the ELF symbol table
TEXT_BEGIN=$(llvm-objdump -t "$ELF" | awk '$NF == "text_begin" {print "0x" $1}')
TEXT_END=$(llvm-objdump -t "$ELF" | awk '$NF == "text_end" {print "0x" $1}')

if [ -z "$TEXT_BEGIN" ] || [ -z "$TEXT_END" ]; then
    echo "ERROR: Could not find text_begin/text_end symbols in $ELF"
    echo "  Ensure the ELF was linked with image.ld which defines these symbols."
    exit 1
fi

echo "SP ELF text section: $TEXT_BEGIN - $TEXT_END"
echo "TCG plugin range:    $RANGE_LO - $RANGE_HI"

# Convert to decimal for arithmetic comparison
TEXT_BEGIN_DEC=$((TEXT_BEGIN))
TEXT_END_DEC=$((TEXT_END))
RANGE_LO_DEC=$((RANGE_LO))
RANGE_HI_DEC=$((RANGE_HI))

if [ "$TEXT_BEGIN_DEC" -lt "$RANGE_LO_DEC" ]; then
    echo "FAIL: text_begin ($TEXT_BEGIN) is below plugin range_lo ($RANGE_LO)"
    echo "  The TCG plugin is not monitoring the start of the .text section."
    exit 1
fi

if [ "$TEXT_END_DEC" -gt "$RANGE_HI_DEC" ]; then
    echo "FAIL: text_end ($TEXT_END) exceeds plugin range_hi ($RANGE_HI)"
    echo "  The SP binary has grown beyond the TCG plugin's monitored range."
    echo "  Update range_hi in coverage-plugin/coverage.c and the -plugin args."
    exit 1
fi

TEXT_SIZE=$(( TEXT_END_DEC - TEXT_BEGIN_DEC ))
RANGE_SIZE=$(( RANGE_HI_DEC - RANGE_LO_DEC ))
echo "OK: SP .text section ($(( TEXT_SIZE / 1024 )) KiB) fits within TCG plugin window ($(( RANGE_SIZE / 1024 )) KiB)"
