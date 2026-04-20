// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: Apache-2.0

//! E2E test: Thermal service via FF-A Direct Request v2.
//!
//! Tests get_temperature (existing), set/get threshold round-trip, and
//! set/get variable round-trip.

#![no_main]
#![no_std]

extern crate alloc;

use ffa::DirectMessagePayload;
use test_support::{response_payload, run_tests, send_direct_req2, TestResults, THERMAL_UUID};
use uefi::prelude::*;

/// EC_THM_GET_TMP opcode.
const EC_THM_GET_TMP: u8 = 0x01;
/// EC_THM_SET_THRS opcode (set threshold).
const EC_THM_SET_THRS: u8 = 0x02;
/// EC_THM_GET_THRS opcode (get threshold).
const EC_THM_GET_THRS: u8 = 0x03;
/// EC_THM_GET_VAR opcode (get variable).
const EC_THM_GET_VAR: u8 = 0x05;
/// EC_THM_SET_VAR opcode (set variable).
const EC_THM_SET_VAR: u8 = 0x06;

#[entry]
fn main() -> Status {
    run_tests(run_thermal_tests)
}

fn run_thermal_tests(results: &mut TestResults, our_id: u16, ec_id: u16) {
    test_thermal_get_temperature(results, our_id, ec_id);
    test_thermal_threshold_round_trip(results, our_id, ec_id);
    test_thermal_variable_round_trip(results, our_id, ec_id);
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

// ---------------------------------------------------------------------------
// Threshold round-trip (THM-08)
// ---------------------------------------------------------------------------

fn build_set_threshold_payload(
    sensor_id: u8,
    timeout: u16,
    low_temp: u32,
    high_temp: u32,
) -> DirectMessagePayload {
    let mut bytes = [0u8; 14 * 8];
    bytes[0] = EC_THM_SET_THRS;
    bytes[1] = sensor_id;
    bytes[3..5].copy_from_slice(&timeout.to_le_bytes());
    bytes[5..9].copy_from_slice(&low_temp.to_le_bytes());
    bytes[9..13].copy_from_slice(&high_temp.to_le_bytes());
    DirectMessagePayload::from_iter(bytes)
}

fn build_get_threshold_payload(sensor_id: u8) -> DirectMessagePayload {
    let mut bytes = [0u8; 14 * 8];
    bytes[0] = EC_THM_GET_THRS;
    bytes[1] = sensor_id;
    DirectMessagePayload::from_iter(bytes)
}

fn test_thermal_threshold_round_trip(results: &mut TestResults, our_id: u16, ec_id: u16) {
    let sensor_id: u8 = 0;
    let timeout: u16 = 200; // 0x00C8
    let low_temp: u32 = 0x1000;
    let high_temp: u32 = 0x2000;

    // --- Set threshold ---
    let set_payload = build_set_threshold_payload(sensor_id, timeout, low_temp, high_temp);
    let resp = match send_direct_req2(our_id, ec_id, &THERMAL_UUID, &set_payload) {
        Some(r) => r,
        None => {
            results.fail(
                "thermal_set_threshold",
                "unexpected response FID on set_threshold",
            );
            return;
        }
    };
    let rp = response_payload(&resp);
    let set_status = rp.u64_at(0) as i64;
    log::info!("  set_threshold response: status={}", set_status);
    if set_status != 0 {
        results.fail("thermal_set_threshold", "non-zero status on set");
        return;
    }
    results.pass("thermal_set_threshold");

    // --- Get threshold ---
    let get_payload = build_get_threshold_payload(sensor_id);
    let resp = match send_direct_req2(our_id, ec_id, &THERMAL_UUID, &get_payload) {
        Some(r) => r,
        None => {
            results.fail(
                "thermal_get_threshold",
                "unexpected response FID on get_threshold",
            );
            return;
        }
    };
    let rp = response_payload(&resp);
    let get_status = rp.u64_at(0) as i64;
    let got_timeout = rp.u32_at(8);
    let got_low = rp.u32_at(12);
    let got_high = rp.u32_at(16);
    log::info!(
        "  get_threshold response: status={}, timeout={}, low={:#x}, high={:#x}",
        get_status,
        got_timeout,
        got_low,
        got_high,
    );
    if get_status != 0 {
        results.fail("thermal_get_threshold", "non-zero status on get");
        return;
    }
    if got_timeout == u32::from(timeout) && got_low == low_temp && got_high == high_temp {
        results.pass("thermal_threshold_round_trip");
    } else {
        results.fail(
            "thermal_threshold_round_trip",
            "threshold values did not round-trip",
        );
    }
}

// ---------------------------------------------------------------------------
// Variable round-trip (THM-08)
// ---------------------------------------------------------------------------

fn build_set_variable_payload(
    instance_id: u8,
    var_uuid: &uuid::Uuid,
    data: u32,
) -> DirectMessagePayload {
    let mut bytes = [0u8; 14 * 8];
    bytes[0] = EC_THM_SET_VAR;
    bytes[1] = instance_id;
    bytes[2..4].copy_from_slice(&4u16.to_le_bytes()); // len = 4
    let uuid_bytes = var_uuid.to_bytes_le();
    bytes[4..20].copy_from_slice(&uuid_bytes);
    bytes[20..24].copy_from_slice(&data.to_le_bytes());
    DirectMessagePayload::from_iter(bytes)
}

fn build_get_variable_payload(instance_id: u8, var_uuid: &uuid::Uuid) -> DirectMessagePayload {
    let mut bytes = [0u8; 14 * 8];
    bytes[0] = EC_THM_GET_VAR;
    bytes[1] = instance_id;
    bytes[2..4].copy_from_slice(&4u16.to_le_bytes()); // len = 4
    let uuid_bytes = var_uuid.to_bytes_le();
    bytes[4..20].copy_from_slice(&uuid_bytes);
    DirectMessagePayload::from_iter(bytes)
}

fn test_thermal_variable_round_trip(results: &mut TestResults, our_id: u16, ec_id: u16) {
    let instance_id: u8 = 0;
    let var_uuid = uuid::uuid!("01020304-0506-0708-090a-0b0c0d0e0f10");
    let data: u32 = 0xCAFE_BABE;

    // --- Set variable ---
    let set_payload = build_set_variable_payload(instance_id, &var_uuid, data);
    let resp = match send_direct_req2(our_id, ec_id, &THERMAL_UUID, &set_payload) {
        Some(r) => r,
        None => {
            results.fail(
                "thermal_set_variable",
                "unexpected response FID on set_variable",
            );
            return;
        }
    };
    let rp = response_payload(&resp);
    let set_status = rp.u64_at(0) as i64;
    log::info!("  set_variable response: status={}", set_status);
    if set_status != 0 {
        results.fail("thermal_set_variable", "non-zero status on set");
        return;
    }
    results.pass("thermal_set_variable");

    // --- Get variable ---
    let get_payload = build_get_variable_payload(instance_id, &var_uuid);
    let resp = match send_direct_req2(our_id, ec_id, &THERMAL_UUID, &get_payload) {
        Some(r) => r,
        None => {
            results.fail(
                "thermal_get_variable",
                "unexpected response FID on get_variable",
            );
            return;
        }
    };
    let rp = response_payload(&resp);
    let get_status = rp.u64_at(0) as i64;
    let got_data = rp.u32_at(8);
    log::info!(
        "  get_variable response: status={}, data={:#x}",
        get_status,
        got_data,
    );
    if get_status != 0 {
        results.fail("thermal_get_variable", "non-zero status on get");
        return;
    }
    if got_data == data {
        results.pass("thermal_variable_round_trip");
    } else {
        results.fail(
            "thermal_variable_round_trip",
            "variable data did not round-trip",
        );
    }
}
