// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: Apache-2.0

//! E2E test: Battery service via FF-A Direct Request v2.
//!
//! Placeholder — test functions will be added in Plan 02.

#![no_main]
#![no_std]

extern crate alloc;

use test_support::{run_tests, TestResults};
use uefi::prelude::*;

#[entry]
fn main() -> Status {
    run_tests(run_battery_tests)
}

fn run_battery_tests(_results: &mut TestResults, _our_id: u16, _ec_id: u16) {
    log::info!("Battery E2E tests — placeholder (see Plan 02)");
}
