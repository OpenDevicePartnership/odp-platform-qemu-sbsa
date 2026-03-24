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
/// PL011 UART0 flag register (FR) on QEMU sbsa-ref.
const UART0_FR: *const u32 = 0x6000_0018 as *const u32;
/// Transmit FIFO full flag in the PL011 FR register.
const UART_FR_TXFF: u32 = 1 << 5;

struct UartLogger;

impl Write for UartLogger {
    fn write_str(&mut self, s: &str) -> core::fmt::Result {
        for b in s.bytes() {
            unsafe {
                while core::ptr::read_volatile(UART0_FR) & UART_FR_TXFF != 0 {}
                core::ptr::write_volatile(UART0_DR, b);
            }
        }
        Ok(())
    }
}

impl Log for UartLogger {
    fn enabled(&self, _metadata: &Metadata) -> bool {
        true
    }

    fn log(&self, record: &Record) {
        let mut uart = UartLogger;
        let _ = writeln!(&mut uart, "{}", record.args());
    }

    fn flush(&self) {}
}

static LOGGER: UartLogger = UartLogger;

/// Install the UART logger as the global `log` backend.
///
/// Sets the max log level to `Trace` so all messages are emitted.
/// Panics if the logger has already been set.
pub fn init() {
    log::set_logger(&LOGGER).expect("UART logger already set");
    log::set_max_level(LevelFilter::Trace);
}
