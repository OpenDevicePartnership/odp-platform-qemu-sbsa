# Coverage plugin — builds libcoverage.so (QEMU TCG plugin)
#
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: Apache-2.0

CC ?= gcc
CFLAGS := -O2 -Wall -Wextra -shared -fPIC -fvisibility=hidden

BUILD_DIR := ../Build

$(BUILD_DIR)/libcoverage.so: coverage.c qemu-plugin.h
	mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $<

.PHONY: clean
clean:
	rm -f $(BUILD_DIR)/libcoverage.so
