// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: Apache-2.0

//! E2E tests for the FwMgmt service via FF-A Direct Request v2.
//!
//! Exercises get_fw_state and get_bid opcodes and validates non-error responses
//! from the secure partition.

#![no_main]
#![no_std]

extern crate alloc;

use ffa::DirectMessagePayload;
use test_support::{response_payload, run_tests, send_direct_req2, TestResults, FWMGMT_UUID};
use uefi::prelude::*;

// FwMgmt protocol command opcodes (byte 0 of payload)
const EC_CAP_GET_FW_STATE: u8 = 0x1;
const EC_CAP_GET_BID: u8 = 0x3;

/// Build a FwMgmt request with just the command byte.
fn fwmgmt_request(cmd: u8) -> DirectMessagePayload {
    let mut bytes = [0u8; 14 * 8];
    bytes[0] = cmd;
    DirectMessagePayload::from_iter(bytes)
}

/// Send a FwMgmt request and return the response payload, or fail the test.
fn fwmgmt_send(
    results: &mut TestResults,
    test_name: &str,
    our_id: u16,
    ec_id: u16,
    cmd: u8,
) -> Option<DirectMessagePayload> {
    let payload = fwmgmt_request(cmd);
    let resp = match send_direct_req2(our_id, ec_id, &FWMGMT_UUID, &payload) {
        Some(r) => r,
        None => {
            results.fail(test_name, "unexpected response FID");
            return None;
        }
    };
    Some(response_payload(&resp))
}

#[entry]
fn main() -> Status {
    run_tests(run_fwmgmt_tests)
}

fn run_fwmgmt_tests(results: &mut TestResults, our_id: u16, ec_id: u16) {
    test_get_fw_state(results, our_id, ec_id);
    test_get_bid(results, our_id, ec_id);
}

/// Test GET_FW_STATE (0x1): validates fw_version != 0 and boot_status == 0x1.
///
/// FwStateRsp layout: fw_version(u16 LE at 0), secure_state(u8 at 2), boot_status(u8 at 3).
fn test_get_fw_state(results: &mut TestResults, our_id: u16, ec_id: u16) {
    let rp = match fwmgmt_send(
        results,
        "fwmgmt_get_fw_state",
        our_id,
        ec_id,
        EC_CAP_GET_FW_STATE,
    ) {
        Some(rp) => rp,
        None => return,
    };

    // Read fw_version as u16 from first 2 bytes of response
    let fw_version_low = rp.u8_at(0) as u16;
    let fw_version_high = rp.u8_at(1) as u16;
    let fw_version = fw_version_low | (fw_version_high << 8);
    let secure_state = rp.u8_at(2);
    let boot_status = rp.u8_at(3);

    log::info!(
        "  get_fw_state: fw_version={:#x} secure_state={:#x} boot_status={:#x}",
        fw_version,
        secure_state,
        boot_status
    );

    if fw_version == 0 {
        results.fail("fwmgmt_get_fw_state", "fw_version is zero");
        return;
    }

    if boot_status == 0x1 {
        results.pass("fwmgmt_get_fw_state");
    } else {
        results.fail("fwmgmt_get_fw_state", "expected boot_status == 0x1");
    }
}

/// Test GET_BID (0x3): validates status == 0 and bid != 0.
///
/// GetBidRsp layout: _status(i64 LE at 0), _bid(u64 LE at 8).
fn test_get_bid(results: &mut TestResults, our_id: u16, ec_id: u16) {
    let rp = match fwmgmt_send(results, "fwmgmt_get_bid", our_id, ec_id, EC_CAP_GET_BID) {
        Some(rp) => rp,
        None => return,
    };

    let status = rp.u64_at(0) as i64;
    let bid = rp.u64_at(8);

    log::info!("  get_bid: status={} bid={:#x}", status, bid);

    if status != 0 {
        results.fail("fwmgmt_get_bid", "non-zero status from SP");
        return;
    }

    if bid != 0 {
        results.pass("fwmgmt_get_bid");
    } else {
        results.fail("fwmgmt_get_bid", "bid is zero");
    }
}
