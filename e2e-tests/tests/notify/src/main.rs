// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: Apache-2.0

//! E2E tests for the Notify service via FF-A Direct Request v2.
//!
//! Tests the setup → destroy lifecycle of notification registration.

#![no_main]
#![no_std]

extern crate alloc;

use ffa::DirectMessagePayload;
use test_support::{response_payload, run_tests, send_direct_req2, TestResults, NOTIFY_UUID};
use uefi::prelude::*;
use uuid::Uuid;

// Message IDs (bits 0-2 of msg_info register)
const MSG_ID_SETUP: u64 = 2;
const MSG_ID_DESTROY: u64 = 3;

// Response msg_info base
const MESSAGE_INFO_DIR_RESP: u64 = 0x100;

// ErrorCode values
const ERROR_CODE_OK: i64 = 0;

// Test UUIDs for sender and receiver (matches unit test UUIDs in notify.rs)
const SENDER_UUID: Uuid = uuid::uuid!("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee");
const RECEIVER_UUID: Uuid = uuid::uuid!("11111111-2222-3333-4444-555555555555");

/// Build a Notify request payload with register layout:
///   reg[0] = reserved (0)
///   reg[1-2] = sender_uuid as LE u128 split into two u64s
///   reg[3-4] = receiver_uuid as LE u128 split into two u64s
///   reg[5] = msg_info (bits 0-2 = message_id)
///   reg[6] = count (lower 9 bits)
///   reg[7..] = notification tuples: cookie(bits63:32) | id(bits31:23) | type(bit0)
fn notify_request(msg_id: u64, count: u8, notifs: &[(u32, u16, u8)]) -> DirectMessagePayload {
    let mut regs = [0u64; 14];
    // regs[0] = reserved
    // regs[1-2] = sender_uuid as LE u128 split into two u64s
    let sender_le = SENDER_UUID.to_u128_le();
    regs[1] = sender_le as u64;
    regs[2] = (sender_le >> 64) as u64;
    // regs[3-4] = receiver_uuid as LE u128 split
    let receiver_le = RECEIVER_UUID.to_u128_le();
    regs[3] = receiver_le as u64;
    regs[4] = (receiver_le >> 64) as u64;
    // regs[5] = msg_info (bits 0-2 = message_id)
    regs[5] = msg_id;
    // regs[6] = count (lower 9 bits)
    regs[6] = count as u64;
    // regs[7..] = notification tuples: cookie(63:32) | id(31:23) | type(bit0)
    for (i, (cookie, id, ntype)) in notifs.iter().enumerate().take(7) {
        regs[7 + i] = ((*cookie as u64) << 32) | ((*id as u64) << 23) | (*ntype as u64);
    }
    let payload_bytes: alloc::vec::Vec<u8> = regs.iter().flat_map(|r| r.to_le_bytes()).collect();
    DirectMessagePayload::from_iter(payload_bytes)
}

#[entry]
fn main() -> Status {
    run_tests(run_notify_tests)
}

fn run_notify_tests(results: &mut TestResults, our_id: u16, ec_id: u16) {
    test_notify_setup_destroy(results, our_id, ec_id);
}

/// Test setup → destroy lifecycle: register a notification, verify OK, then destroy it.
fn test_notify_setup_destroy(results: &mut TestResults, our_id: u16, ec_id: u16) {
    // --- Setup: register one notification (cookie=0x1234, id=5, type=Global) ---
    let setup_payload = notify_request(MSG_ID_SETUP, 1, &[(0x1234, 5, 0)]);
    let setup_resp = match send_direct_req2(our_id, ec_id, &NOTIFY_UUID, &setup_payload) {
        Some(r) => r,
        None => {
            results.fail("notify_setup", "unexpected response FID");
            return;
        }
    };
    let setup_rp = response_payload(&setup_resp);
    let setup_msg_info = setup_rp.register_at(5);
    let setup_status = setup_rp.register_at(6) as i64;

    log::info!(
        "  notify_setup: msg_info={:#x} status={}",
        setup_msg_info,
        setup_status
    );

    if setup_msg_info != MESSAGE_INFO_DIR_RESP + MSG_ID_SETUP {
        results.fail("notify_setup", "unexpected msg_info in setup response");
        return;
    }
    if setup_status != ERROR_CODE_OK {
        results.fail("notify_setup", "non-OK status from setup");
        return;
    }
    results.pass("notify_setup");

    // --- Destroy: remove the same notification (cookie=0x1234, id=5, type=Global) ---
    let destroy_payload = notify_request(MSG_ID_DESTROY, 1, &[(0x1234, 5, 0)]);
    let destroy_resp = match send_direct_req2(our_id, ec_id, &NOTIFY_UUID, &destroy_payload) {
        Some(r) => r,
        None => {
            results.fail("notify_destroy", "unexpected response FID");
            return;
        }
    };
    let destroy_rp = response_payload(&destroy_resp);
    let destroy_msg_info = destroy_rp.register_at(5);
    let destroy_status = destroy_rp.register_at(6) as i64;

    log::info!(
        "  notify_destroy: msg_info={:#x} status={}",
        destroy_msg_info,
        destroy_status
    );

    if destroy_msg_info != MESSAGE_INFO_DIR_RESP + MSG_ID_DESTROY {
        results.fail("notify_destroy", "unexpected msg_info in destroy response");
        return;
    }
    if destroy_status != ERROR_CODE_OK {
        results.fail("notify_destroy", "non-OK status from destroy");
        return;
    }
    results.pass("notify_destroy");
}
