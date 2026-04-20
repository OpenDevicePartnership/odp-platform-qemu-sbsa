// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: Apache-2.0

//! E2E tests for the Battery service via FF-A Direct Request v2.
//!
//! Exercises key Battery opcodes and validates non-empty responses
//! from the secure partition.

#![no_main]
#![no_std]

extern crate alloc;

use ffa::DirectMessagePayload;
use test_support::{response_payload, run_tests, send_direct_req2, TestResults, BATTERY_UUID};
use uefi::prelude::*;

// Battery protocol command opcodes (byte 0 of payload)
const EC_BAT_GET_BIX: u8 = 0x1;
const EC_BAT_GET_BST: u8 = 0x2;
const EC_BAT_GET_PSR: u8 = 0x3;
const EC_BAT_GET_STA: u8 = 0xf;

/// Build a battery request with just the command byte.
fn bat_request(cmd: u8) -> DirectMessagePayload {
    let mut bytes = [0u8; 14 * 8];
    bytes[0] = cmd;
    DirectMessagePayload::from_iter(bytes)
}

/// Send a battery request and return the response payload, or fail the test.
fn bat_send(
    results: &mut TestResults,
    test_name: &str,
    our_id: u16,
    ec_id: u16,
    cmd: u8,
) -> Option<DirectMessagePayload> {
    let payload = bat_request(cmd);
    let resp = match send_direct_req2(our_id, ec_id, &BATTERY_UUID, &payload) {
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
    run_tests(run_battery_tests)
}

fn run_battery_tests(results: &mut TestResults, our_id: u16, ec_id: u16) {
    test_get_bix(results, our_id, ec_id);
    test_get_bst(results, our_id, ec_id);
    test_get_psr(results, our_id, ec_id);
    test_get_sta(results, our_id, ec_id);
}

/// Test GET_BIX (0x1): validates non-zero last_full_charge, cycle_count, present_volt.
fn test_get_bix(results: &mut TestResults, our_id: u16, ec_id: u16) {
    let rp = match bat_send(results, "battery_get_bix", our_id, ec_id, EC_BAT_GET_BIX) {
        Some(rp) => rp,
        None => return,
    };

    // BixRsp layout (u32 LE each): events(0), status(4), last_full_charge(8),
    // cycle_count(12), state(16), present_rate(20), remain_cap(24),
    // present_volt(28), psr_state(32), psr_max_out(36), psr_max_in(40)
    let last_full_charge = rp.u32_at(8);
    let cycle_count = rp.u32_at(12);
    let present_volt = rp.u32_at(28);

    log::info!(
        "  get_bix: last_full_charge={} cycle_count={} present_volt={}",
        last_full_charge,
        cycle_count,
        present_volt
    );

    if last_full_charge != 0 && cycle_count != 0 && present_volt != 0 {
        results.pass("battery_get_bix");
    } else {
        results.fail("battery_get_bix", "response contains unexpected zeros");
    }
}

/// Test GET_BST (0x2): validates non-zero state, present_rate, remaining_cap, present_volt.
fn test_get_bst(results: &mut TestResults, our_id: u16, ec_id: u16) {
    let rp = match bat_send(results, "battery_get_bst", our_id, ec_id, EC_BAT_GET_BST) {
        Some(rp) => rp,
        None => return,
    };

    // BstRsp layout (u32 LE each): state(0), present_rate(4), remaining_cap(8), present_volt(12)
    let state = rp.u32_at(0);
    let present_rate = rp.u32_at(4);
    let remaining_cap = rp.u32_at(8);
    let present_volt = rp.u32_at(12);

    log::info!(
        "  get_bst: state={:#x} rate={} cap={} volt={}",
        state,
        present_rate,
        remaining_cap,
        present_volt
    );

    if state != 0 && present_rate != 0 && remaining_cap != 0 && present_volt != 0 {
        results.pass("battery_get_bst");
    } else {
        results.fail("battery_get_bst", "response contains unexpected zeros");
    }
}

/// Test GET_PSR (0x3): validates psr_state == 0x1 (AC adapter present).
fn test_get_psr(results: &mut TestResults, our_id: u16, ec_id: u16) {
    let rp = match bat_send(results, "battery_get_psr", our_id, ec_id, EC_BAT_GET_PSR) {
        Some(rp) => rp,
        None => return,
    };

    // PsrRsp layout: psr_state(u32 at 0)
    let psr_state = rp.u32_at(0);

    log::info!("  get_psr: psr_state={:#x}", psr_state);

    if psr_state == 0x1 {
        results.pass("battery_get_psr");
    } else {
        results.fail("battery_get_psr", "expected psr_state == 0x1 (AC present)");
    }
}

/// Test GET_STA (0xf): validates sta_status has all 5 status bits set (0x1F).
fn test_get_sta(results: &mut TestResults, our_id: u16, ec_id: u16) {
    let rp = match bat_send(results, "battery_get_sta", our_id, ec_id, EC_BAT_GET_STA) {
        Some(rp) => rp,
        None => return,
    };

    // StaRsp layout: sta_status(u32 at 0)
    let sta_status = rp.u32_at(0);

    log::info!("  get_sta: sta_status={:#x}", sta_status);

    if sta_status & 0x1F == 0x1F {
        results.pass("battery_get_sta");
    } else {
        results.fail("battery_get_sta", "expected all 5 status bits set (0x1F)");
    }
}
