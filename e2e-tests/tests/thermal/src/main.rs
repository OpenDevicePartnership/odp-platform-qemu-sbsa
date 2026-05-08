//! E2E test: Thermal service get_temperature via FF-A Direct Request v2.
//!
//! SPDX-License-Identifier: MIT
//!

#![no_main]
#![no_std]

extern crate alloc;

use ffa::DirectMessagePayload;
use test_support::{response_payload, run_tests, send_direct_req2, TestResults, THERMAL_UUID};
use uefi::prelude::*;

/// EC_THM_GET_TMP opcode.
const EC_THM_GET_TMP: u8 = 0x01;

#[entry]
fn main() -> Status {
    run_tests(test_thermal_get_temperature)
}

fn test_thermal_get_temperature(results: &mut TestResults, our_id: u16, ec_id: u16) {
    // Build get_temperature request payload.
    // The Thermal service expects a DirectMessagePayload where:
    //   byte 0 = command (EC_THM_GET_TMP = 0x01)
    //   byte 1 = sensor_id (0x00)
    let sensor_id: u8 = 0;
    let payload = DirectMessagePayload::from_iter(
        [EC_THM_GET_TMP, sensor_id]
            .into_iter()
            .chain(core::iter::repeat_n(0u8, 14 * 8 - 2)),
    );

    let resp = match send_direct_req2(our_id, ec_id, &THERMAL_UUID, &payload) {
        Some(r) => r,
        None => {
            results.fail("thermal_get_temperature", "unexpected response FID");
            return;
        }
    };

    // Response layout: byte 0..8 = status (i64), byte 8..16 = temperature (u64)
    let resp_payload = response_payload(&resp);
    let status = resp_payload.u64_at(0) as i64;
    let temperature = resp_payload.u64_at(8);

    log::info!(
        "  get_temperature response: status={}, temp={:#x}",
        status,
        temperature,
    );

    if status == 0 {
        results.pass("thermal_get_temperature");
    } else {
        results.fail("thermal_get_temperature", "non-zero status from SP");
    }
}
