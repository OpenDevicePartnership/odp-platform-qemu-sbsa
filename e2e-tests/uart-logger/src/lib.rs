// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: Apache-2.0

//! Minimal `log` backend that writes to PL011 UART0 on the QEMU sbsa-ref
//! machine (MMIO address `0x6000_0000`).
//!
//! Call [`init`] once at startup to install the logger globally.

#![no_std]

use core::fmt::Write;
use log::{LevelFilter, Log, Metadata, Record};

/// PL011 UART0 data register on QEMU sbsa-ref.
const UART0_DR: *mut u8 = 0x6000_0000 as *mut u8;

struct UartLogger;

impl Write for UartLogger {
    fn write_str(&mut self, s: &str) -> core::fmt::Result {
        for b in s.bytes() {
            unsafe { core::ptr::write_volatile(UART0_DR, b) };
        }
        Ok(())
    }
}

impl Log for UartLogger {
    fn enabled(&self, _metadata: &Metadata) -> bool {
        true
    }

    fn log(&self, record: &Record) {
        let _ = writeln!(UartLogger, "{}", record.args());
    }

    fn flush(&self) {}
}

static LOGGER: UartLogger = UartLogger;

/// Install the UART logger as the global `log` backend.
///
/// Sets the max log level to `Trace` so all messages are emitted.
pub fn init() {
    log::set_logger(&LOGGER).ok();
    log::set_max_level(LevelFilter::Trace);
}
