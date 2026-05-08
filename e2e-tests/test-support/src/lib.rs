//! Shared E2E test support utilities for FF-A based UEFI tests.
//!
//! SPDX-License-Identifier: MIT
//!

#![no_std]

use ffa::{DirectMessagePayload, Function, IdGet, Version};
use uefi::prelude::*;
use uuid::Uuid;

/// EC Thermal service UUID: 31f56da7-593c-4d72-a4b3-8fc7171ac073
///
/// Used for partition discovery because the BIOS includes a separate SP that
/// also claims the TPM UUID. Both services run in the same EC SP.
pub const THERMAL_UUID: Uuid = uuid::uuid!("31f56da7-593c-4d72-a4b3-8fc7171ac073");

pub const FFA_MSG_SEND_DIRECT_REQ2: u64 = 0xC400008D;
pub const FFA_MSG_SEND_DIRECT_RESP2: u64 = 0xC400008E;
const FFA_INTERRUPT: u64 = 0x84000062;
const FFA_YIELD: u64 = 0x8400006C;
const FFA_RUN: u64 = 0x8400006D;

/// Simple test result tracking.
#[derive(Default)]
pub struct TestResults {
    passed: u32,
    failed: u32,
}

impl TestResults {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn pass(&mut self, name: &str) {
        self.passed += 1;
        log::info!("[PASS] {}", name);
    }

    pub fn fail(&mut self, name: &str, reason: &str) {
        self.failed += 1;
        log::error!("[FAIL] {} - {}", name, reason);
    }

    pub fn summary(&self) -> bool {
        log::info!(
            "--- Results: {} passed, {} failed ---",
            self.passed,
            self.failed
        );
        self.failed == 0
    }
}

/// Test FFA version negotiation (requires >= 1.2).
pub fn test_ffa_version(results: &mut TestResults) {
    match Version::new().exec() {
        Ok(version) => {
            let major = version.major();
            let minor = version.minor();
            log::info!("  FFA version: {}.{}", major, minor);
            if major >= 1 && (major > 1 || minor >= 2) {
                results.pass("ffa_version");
            } else {
                results.fail("ffa_version", "version too old, need >= 1.2");
            }
        }
        Err(e) => {
            results.fail("ffa_version", "SMC call failed");
            log::error!("  error: {:?}", e);
        }
    }
}

/// Test FFA_ID_GET and return our partition ID.
pub fn test_ffa_id_get(results: &mut TestResults) -> Option<u16> {
    match IdGet.exec() {
        Ok(id_result) => {
            log::info!("  Our partition ID: {:#06x}", id_result.id);
            results.pass("ffa_id_get");
            Some(id_result.id)
        }
        Err(e) => {
            results.fail("ffa_id_get", "SMC call failed");
            log::error!("  error: {:?}", e);
            None
        }
    }
}

/// Discover the EC partition by thermal UUID and return its ID.
pub fn test_partition_discovery(results: &mut TestResults) -> Option<u16> {
    match ffa::ffa_partition_info_get_regs(&THERMAL_UUID) {
        Ok((count, partitions)) => {
            log::debug!("  partition_info: count={}", count);
            for (i, part) in partitions.iter().enumerate().take(count) {
                log::debug!(
                    "    [{}] id={:#06x} ctx={} props={:#010x}",
                    i,
                    part.partition_id,
                    part.execution_ctx_count,
                    part.properties,
                );
            }
            if count > 0 {
                let id = partitions[0].partition_id;
                log::info!(
                    "  Found EC partition: id={:#06x} ctx={} props={:#010x}",
                    id,
                    partitions[0].execution_ctx_count,
                    partitions[0].properties,
                );
                results.pass("partition_discovery");
                Some(id)
            } else {
                results.fail(
                    "partition_discovery",
                    "no partitions found for thermal UUID",
                );
                None
            }
        }
        Err(e) => {
            results.fail("partition_discovery", "PARTITION_INFO_GET_REGS failed");
            log::error!("  error: {:?}", e);
            None
        }
    }
}

/// Send an FF-A Direct Request v2 and handle YIELD/INTERRUPT retries.
///
/// Returns the raw SMC response registers on success (DIRECT_RESP2), or `None`
/// if the response FID was unexpected after retries.
pub fn send_direct_req2(
    our_id: u16,
    dest_id: u16,
    uuid: &Uuid,
    payload: &DirectMessagePayload,
) -> Option<[u64; 18]> {
    let x1 = ((our_id as u64) << 16) | (dest_id as u64);
    let (uuid_high, uuid_low) = uuid.as_u64_pair();
    let x2 = uuid_high.to_be();
    let x3 = uuid_low.to_be();

    let mut payload_regs = [0u64; 14];
    for (i, reg) in payload.registers_iter().enumerate().take(14) {
        payload_regs[i] = reg;
    }

    let mut resp = ffa::raw_smc(
        FFA_MSG_SEND_DIRECT_REQ2,
        x1,
        x2,
        x3,
        payload_regs[0],
        payload_regs[1],
        payload_regs[2],
        payload_regs[3],
        payload_regs[4],
        payload_regs[5],
        payload_regs[6],
        payload_regs[7],
        payload_regs[8],
        payload_regs[9],
        payload_regs[10],
        payload_regs[11],
        payload_regs[12],
        payload_regs[13],
    );

    let mut retries = 0;
    while (resp[0] == FFA_YIELD || resp[0] == FFA_INTERRUPT) && retries < 100 {
        log::debug!(
            "  FFA_YIELD/INTERRUPT (x0={:#x}), calling FFA_RUN...",
            resp[0]
        );
        let run_arg = (dest_id as u64) << 16;
        resp = ffa::raw_smc(
            FFA_RUN, run_arg, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        );
        retries += 1;
    }

    if resp[0] == FFA_MSG_SEND_DIRECT_RESP2 {
        Some(resp)
    } else {
        log::error!(
            "  x0={:#018x} (expected DIRECT_RESP2={:#x})",
            resp[0],
            FFA_MSG_SEND_DIRECT_RESP2
        );
        None
    }
}

/// Extract the response payload (x4..x17) from raw SMC result registers.
pub fn response_payload(resp: &[u64; 18]) -> DirectMessagePayload {
    DirectMessagePayload::from_iter(resp[4..18].iter().flat_map(|r| r.to_le_bytes()))
}

/// Common test harness: initialises UEFI + UART logging, runs the standard
/// FFA setup tests (version, id_get, partition_discovery), then invokes the
/// caller's service-specific tests and returns the appropriate UEFI status.
///
/// The closure receives `(results, our_id, ec_id)` so it can send direct
/// requests to the EC secure partition.
pub fn run_tests(f: impl FnOnce(&mut TestResults, u16, u16)) -> Status {
    uefi::helpers::init().unwrap();
    uart_logger::init();
    log::info!("=== EC Secure Partition E2E Tests ===");

    let mut results = TestResults::new();

    test_ffa_version(&mut results);
    let our_id = test_ffa_id_get(&mut results);
    let ec_id = test_partition_discovery(&mut results);

    if let (Some(src), Some(dst)) = (our_id, ec_id) {
        f(&mut results, src, dst);
    }

    if results.summary() {
        Status::SUCCESS
    } else {
        Status::ABORTED
    }
}
