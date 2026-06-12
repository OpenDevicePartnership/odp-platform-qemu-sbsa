//! E2E tests for the TPM service via FF-A Direct Request v2.
//!
//! SPDX-License-Identifier: MIT
//!
//! Exercises the TPM service's opcode routing, parameter validation,
//! state-machine enforcement, and access control by sending various
//! FF-A messages and checking the response status codes.

#![no_main]
#![no_std]

extern crate alloc;

use ffa::DirectMessagePayload;
use test_support::{response_payload, run_tests, send_direct_req2, TestResults};
use uefi::prelude::*;
use uuid::Uuid;

/// TPM 2.0 service UUID: 17b862a4-1806-4faf-86b3-089a58353861
const TPM_UUID: Uuid = uuid::uuid!("17b862a4-1806-4faf-86b3-089a58353861");

// ---------------------------------------------------------------------------
// TPM Service Function IDs (opcodes placed in Arg0 / register x4)
// ---------------------------------------------------------------------------
const TPM2_FFA_GET_INTERFACE_VERSION: u64 = 0x0f00_0001;
const TPM2_FFA_GET_FEATURE_INFO: u64 = 0x0f00_0101;
const TPM2_FFA_START: u64 = 0x0f00_0201;
const TPM2_FFA_REGISTER_FOR_NOTIFICATION: u64 = 0x0f00_0301;
const TPM2_FFA_UNREGISTER_FOR_NOTIFICATION: u64 = 0x0f00_0401;
const TPM2_FFA_FINISH_NOTIFIED: u64 = 0x0f00_0501;
const TPM2_FFA_MANAGE_LOCALITY: u64 = 0x1f00_0001;

// ---------------------------------------------------------------------------
// TPM Service Status Codes (returned in Arg0 / register x4 of response)
// ---------------------------------------------------------------------------
const TPM2_FFA_SUCCESS_OK: u64 = 0x0500_0001;
const TPM2_FFA_SUCCESS_OK_RESULTS: u64 = 0x0500_0002;
const TPM2_FFA_NO_FUNC: u64 = 0x8e00_0001;
const TPM2_FFA_NOT_SUP: u64 = 0x8e00_0002;
const TPM2_FFA_INV_ARG: u64 = 0x8e00_0005;
const TPM2_FFA_INV_CRB_CTRL_DATA: u64 = 0x8e00_0006;
const TPM2_FFA_DENIED: u64 = 0x8e00_000a;

// ---------------------------------------------------------------------------
// Start function qualifiers (placed in Arg1 / register x5)
// ---------------------------------------------------------------------------
const START_QUALIFIER_COMMAND: u64 = 0x0;
const START_QUALIFIER_LOCALITY: u64 = 0x1;

// ---------------------------------------------------------------------------
// ManageLocality operations (placed in Arg1 / register x5)
// ---------------------------------------------------------------------------
const MANAGE_LOCALITY_OPEN: u64 = 0x0;
const MANAGE_LOCALITY_CLOSE: u64 = 0x1;

// ---------------------------------------------------------------------------
// Test-only opcode: write CRB register bits in the SP's internal CRB
// ---------------------------------------------------------------------------
const TPM2_FFA_TEST_WRITE_CRB: u64 = 0xDE00_0001;

// TestWriteCrb operations (placed in Arg1 / register x5)
const TEST_CRB_SET_REQUEST_ACCESS: u64 = 0;
const TEST_CRB_SET_RELINQUISH: u64 = 1;
const TEST_CRB_SET_CMD_READY: u64 = 2;
const TEST_CRB_SET_GO_IDLE: u64 = 3;
#[allow(dead_code)]
const TEST_CRB_SET_START: u64 = 4;

/// Build a TPM request payload from (opcode, function, locality).
///
/// The TPM service reads three registers from the FF-A payload:
///   Arg0 (x4) = opcode
///   Arg1 (x5) = function qualifier
///   Arg2 (x6) = locality
fn tpm_request(opcode: u64, function: u64, locality: u64) -> DirectMessagePayload {
    let bytes: alloc::vec::Vec<u8> = opcode
        .to_le_bytes()
        .into_iter()
        .chain(function.to_le_bytes())
        .chain(locality.to_le_bytes())
        .chain(core::iter::repeat_n(0u8, 14 * 8 - 24))
        .collect();
    DirectMessagePayload::from_iter(bytes)
}

/// Send a TPM request and return (status, payload) from the response.
fn tpm_send(
    results: &mut TestResults,
    test_name: &str,
    our_id: u16,
    ec_id: u16,
    payload: &DirectMessagePayload,
) -> Option<(u64, u64)> {
    let resp = match send_direct_req2(our_id, ec_id, &TPM_UUID, payload) {
        Some(r) => r,
        None => {
            results.fail(test_name, "unexpected response FID");
            return None;
        }
    };
    let rp = response_payload(&resp);
    Some((rp.u64_at(0), rp.u64_at(8)))
}

/// Send a TPM request and assert the response status matches `expected`.
#[allow(clippy::too_many_arguments)]
fn expect_status(
    results: &mut TestResults,
    test_name: &str,
    our_id: u16,
    ec_id: u16,
    opcode: u64,
    function: u64,
    locality: u64,
    expected: u64,
) {
    let payload = tpm_request(opcode, function, locality);
    let (status, _) = match tpm_send(results, test_name, our_id, ec_id, &payload) {
        Some(v) => v,
        None => return,
    };
    log::info!("  {}: status={:#x}", test_name, status);
    if status == expected {
        results.pass(test_name);
    } else {
        results.fail(test_name, "unexpected status");
    }
}

#[entry]
fn main() -> Status {
    run_tests(run_tpm_tests)
}

fn run_tpm_tests(results: &mut TestResults, our_id: u16, ec_id: u16) {
    // Stateless tests (don't depend on or change locality state)
    test_get_interface_version(results, our_id, ec_id);
    // GetFeatureInfo is not implemented — should return NOT_SUP.
    expect_status(
        results,
        "tpm_get_feature_info",
        our_id,
        ec_id,
        TPM2_FFA_GET_FEATURE_INFO,
        0,
        0,
        TPM2_FFA_NOT_SUP,
    );
    // An unknown opcode should return NO_FUNC.
    expect_status(
        results,
        "tpm_invalid_opcode",
        our_id,
        ec_id,
        0xDEAD_BEEF,
        0,
        0,
        TPM2_FFA_NO_FUNC,
    );
    // Start(COMMAND) on closed locality 2 → DENIED (per DEN0138, DENIED is
    // for "TPM has disabled requests at this locality"). Localities 2..=4
    // are closed by default after SP init; localities 0..=1 are open.
    expect_status(
        results,
        "tpm_start_closed_locality",
        our_id,
        ec_id,
        TPM2_FFA_START,
        START_QUALIFIER_COMMAND,
        2,
        TPM2_FFA_DENIED,
    );
    // Start with out-of-range locality (>= 5) → INV_ARG.
    expect_status(
        results,
        "tpm_start_invalid_locality",
        our_id,
        ec_id,
        TPM2_FFA_START,
        START_QUALIFIER_COMMAND,
        5,
        TPM2_FFA_INV_ARG,
    );
    // Start(LOCALITY) on closed locality 2 → DENIED (same reasoning as above).
    expect_status(
        results,
        "tpm_start_locality_qualifier_closed",
        our_id,
        ec_id,
        TPM2_FFA_START,
        START_QUALIFIER_LOCALITY,
        2,
        TPM2_FFA_DENIED,
    );
    // RegisterForNotification → NOT_SUP.
    expect_status(
        results,
        "tpm_register_for_notification",
        our_id,
        ec_id,
        TPM2_FFA_REGISTER_FOR_NOTIFICATION,
        0,
        0,
        TPM2_FFA_NOT_SUP,
    );
    // UnregisterForNotification → NOT_SUP.
    expect_status(
        results,
        "tpm_unregister_for_notification",
        our_id,
        ec_id,
        TPM2_FFA_UNREGISTER_FOR_NOTIFICATION,
        0,
        0,
        TPM2_FFA_NOT_SUP,
    );
    // FinishNotified → NOT_SUP.
    expect_status(
        results,
        "tpm_finish_notified",
        our_id,
        ec_id,
        TPM2_FFA_FINISH_NOTIFIED,
        0,
        0,
        TPM2_FFA_NOT_SUP,
    );

    // ManageLocality tests (SP built with test-bypass-locality-check)
    // ManageLocality(OPEN, locality=0) should succeed.
    expect_status(
        results,
        "tpm_manage_locality_open",
        our_id,
        ec_id,
        TPM2_FFA_MANAGE_LOCALITY,
        MANAGE_LOCALITY_OPEN,
        0,
        TPM2_FFA_SUCCESS_OK,
    );
    // ManageLocality with invalid operation (not OPEN or CLOSE) → INV_ARG.
    expect_status(
        results,
        "tpm_manage_locality_invalid_op",
        our_id,
        ec_id,
        TPM2_FFA_MANAGE_LOCALITY,
        0x2,
        0,
        TPM2_FFA_INV_ARG,
    );

    // Tests requiring open locality (locality 0 was opened above)
    // Start(COMMAND) on open locality with no command queued in CRB
    // → INV_CRB_CTRL_DATA (per DEN0138, the CRB control data is invalid
    // because no operation is requested). Note: the test name is historical;
    // in the live SP+EC scenario, active_locality is set to 0 by the EC's
    // earlier Start(LOCALITY,0) traffic, so this exercises the "no command
    // queued" path rather than the "locality mismatch" branch.
    expect_status(
        results,
        "tpm_start_command_locality_mismatch",
        our_id,
        ec_id,
        TPM2_FFA_START,
        START_QUALIFIER_COMMAND,
        0,
        TPM2_FFA_INV_CRB_CTRL_DATA,
    );
    // Start with invalid function qualifier → INV_ARG.
    expect_status(
        results,
        "tpm_start_invalid_function",
        our_id,
        ec_id,
        TPM2_FFA_START,
        0x2,
        0,
        TPM2_FFA_INV_ARG,
    );
    // Start(LOCALITY) with no CRB request/relinquish bits → INV_CRB_CTRL_DATA
    // (per DEN0138, the locality_control register has no operation requested).
    expect_status(
        results,
        "tpm_start_locality_no_crb_bits",
        our_id,
        ec_id,
        TPM2_FFA_START,
        START_QUALIFIER_LOCALITY,
        0,
        TPM2_FFA_INV_CRB_CTRL_DATA,
    );
    // Start(COMMAND) with no command queued in CRB → INV_CRB_CTRL_DATA.
    // Same code path as tpm_start_command_locality_mismatch above.
    expect_status(
        results,
        "tpm_start_command_idle_no_bits",
        our_id,
        ec_id,
        TPM2_FFA_START,
        START_QUALIFIER_COMMAND,
        0,
        TPM2_FFA_INV_CRB_CTRL_DATA,
    );

    // CRB state machine tests — exercises handle_command + tpm_sst
    // These use the test-only TestWriteCrb opcode to set internal CRB bits,
    // then trigger the state machine via Start(LOCALITY/COMMAND).
    test_crb_state_machine(results, our_id, ec_id);

    // Close locality
    expect_status(
        results,
        "tpm_manage_locality_close",
        our_id,
        ec_id,
        TPM2_FFA_MANAGE_LOCALITY,
        MANAGE_LOCALITY_CLOSE,
        0,
        TPM2_FFA_SUCCESS_OK,
    );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// Verify GetInterfaceVersion returns success and the correct v1.0 version.
fn test_get_interface_version(results: &mut TestResults, our_id: u16, ec_id: u16) {
    let payload = tpm_request(TPM2_FFA_GET_INTERFACE_VERSION, 0, 0);
    let (status, version) = match tpm_send(
        results,
        "tpm_get_interface_version",
        our_id,
        ec_id,
        &payload,
    ) {
        Some(v) => v,
        None => return,
    };

    log::info!(
        "  get_interface_version: status={:#x}, version={:#x}",
        status,
        version
    );

    if status != TPM2_FFA_SUCCESS_OK_RESULTS {
        results.fail("tpm_get_interface_version", "unexpected status");
        return;
    }

    // Version should be (major << 16) | minor = (1 << 16) | 0 = 0x10000
    if version != 0x1_0000 {
        results.fail(
            "tpm_get_interface_version",
            "expected version 1.0 (0x10000)",
        );
        return;
    }

    results.pass("tpm_get_interface_version");
}

/// Helper: send TestWriteCrb and assert OK.
fn test_write_crb(
    results: &mut TestResults,
    test_name: &str,
    our_id: u16,
    ec_id: u16,
    operation: u64,
    locality: u64,
) -> bool {
    let payload = tpm_request(TPM2_FFA_TEST_WRITE_CRB, operation, locality);
    let (status, _) = match tpm_send(results, test_name, our_id, ec_id, &payload) {
        Some(v) => v,
        None => return false,
    };
    if status != TPM2_FFA_SUCCESS_OK {
        results.fail(test_name, "TestWriteCrb failed");
        return false;
    }
    true
}

/// Exercises the full CRB state machine through handle_command and
/// handle_locality_request, driving the SST layer (tpm_sst.rs):
///
///   1. Set REQUEST_ACCESS → Start(LOCALITY) → sst.locality_request → active=0
///   2. Set CMD_READY → Start(COMMAND) → handle_command IDLE→READY (sst.cmd_ready)
///   3. Set GO_IDLE → Start(COMMAND) → handle_command READY→IDLE (sst.go_idle)
///   4. Set RELINQUISH → Start(LOCALITY) → sst.locality_relinquish → active=NONE
fn test_crb_state_machine(results: &mut TestResults, our_id: u16, ec_id: u16) {
    // -- Step 1: Request locality 0 via sst.locality_request ---------------
    if !test_write_crb(
        results,
        "tpm_crb_sm",
        our_id,
        ec_id,
        TEST_CRB_SET_REQUEST_ACCESS,
        0,
    ) {
        return;
    }
    let payload = tpm_request(TPM2_FFA_START, START_QUALIFIER_LOCALITY, 0);
    let (status, _) = match tpm_send(results, "tpm_crb_locality_request", our_id, ec_id, &payload) {
        Some(v) => v,
        None => return,
    };
    log::info!("  crb_locality_request: status={:#x}", status);
    if status != TPM2_FFA_SUCCESS_OK {
        results.fail(
            "tpm_crb_locality_request",
            "expected OK from locality request",
        );
        return;
    }
    results.pass("tpm_crb_locality_request");

    // -- Step 2: IDLE → READY via sst.cmd_ready ----------------------------
    if !test_write_crb(
        results,
        "tpm_crb_sm",
        our_id,
        ec_id,
        TEST_CRB_SET_CMD_READY,
        0,
    ) {
        return;
    }
    let payload = tpm_request(TPM2_FFA_START, START_QUALIFIER_COMMAND, 0);
    let (status, _) = match tpm_send(results, "tpm_crb_idle_to_ready", our_id, ec_id, &payload) {
        Some(v) => v,
        None => return,
    };
    log::info!("  crb_idle_to_ready: status={:#x}", status);
    if status != TPM2_FFA_SUCCESS_OK {
        results.fail("tpm_crb_idle_to_ready", "expected OK for IDLE→READY");
        return;
    }
    results.pass("tpm_crb_idle_to_ready");

    // -- Step 3: READY → IDLE via sst.go_idle ------------------------------
    if !test_write_crb(
        results,
        "tpm_crb_sm",
        our_id,
        ec_id,
        TEST_CRB_SET_GO_IDLE,
        0,
    ) {
        return;
    }
    let payload = tpm_request(TPM2_FFA_START, START_QUALIFIER_COMMAND, 0);
    let (status, _) = match tpm_send(results, "tpm_crb_ready_to_idle", our_id, ec_id, &payload) {
        Some(v) => v,
        None => return,
    };
    log::info!("  crb_ready_to_idle: status={:#x}", status);
    if status != TPM2_FFA_SUCCESS_OK {
        results.fail("tpm_crb_ready_to_idle", "expected OK for READY→IDLE");
        return;
    }
    results.pass("tpm_crb_ready_to_idle");

    // -- Step 4: Relinquish locality 0 via sst.locality_relinquish ---------
    if !test_write_crb(
        results,
        "tpm_crb_sm",
        our_id,
        ec_id,
        TEST_CRB_SET_RELINQUISH,
        0,
    ) {
        return;
    }
    let payload = tpm_request(TPM2_FFA_START, START_QUALIFIER_LOCALITY, 0);
    let (status, _) = match tpm_send(
        results,
        "tpm_crb_locality_relinquish",
        our_id,
        ec_id,
        &payload,
    ) {
        Some(v) => v,
        None => return,
    };
    log::info!("  crb_locality_relinquish: status={:#x}", status);
    if status != TPM2_FFA_SUCCESS_OK {
        results.fail(
            "tpm_crb_locality_relinquish",
            "expected OK from locality relinquish",
        );
        return;
    }
    results.pass("tpm_crb_locality_relinquish");
}
