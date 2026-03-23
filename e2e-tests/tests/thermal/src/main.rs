// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: Apache-2.0

//! E2E test: Thermal service get_temperature via FF-A Direct Request v2.
//!
//! This UEFI application:
//! 1. Negotiates FF-A v1.2 with the SPMC
//! 2. Discovers the EC Secure Partition (0x8002) by Thermal service UUID
//! 3. Sends EC_THM_GET_TMP (opcode 0x01) to read temperature
//! 4. Validates the response and prints PASS/FAIL over serial
//! 5. Shuts down QEMU

#![no_main]
#![no_std]

extern crate alloc;

use ffa::{
    DirectMessagePayload, Function, IdGet,
    Version,
};
use uefi::prelude::*;
use uefi::runtime::{self, ResetType};
use uuid::Uuid;

/// EC Thermal service UUID: 31f56da7-593c-4d72-a4b3-8fc7171ac073
const THERMAL_UUID: Uuid = uuid::uuid!("31f56da7-593c-4d72-a4b3-8fc7171ac073");

/// EC_THM_GET_TMP opcode.
const EC_THM_GET_TMP: u8 = 0x01;

/// Simple test result tracking.
struct TestResults {
    passed: u32,
    failed: u32,
}

impl TestResults {
    fn new() -> Self {
        Self {
            passed: 0,
            failed: 0,
        }
    }

    fn pass(&mut self, name: &str) {
        self.passed += 1;
        log::info!("[PASS] {}", name);
    }

    fn fail(&mut self, name: &str, reason: &str) {
        self.failed += 1;
        log::error!("[FAIL] {} - {}", name, reason);
    }

    fn summary(&self) -> bool {
        log::info!(
            "--- Results: {} passed, {} failed ---",
            self.passed,
            self.failed
        );
        self.failed == 0
    }
}

#[entry]
fn main() -> Status {
    uefi::helpers::init().unwrap();
    uart_logger::init();
    log::info!("=== EC Secure Partition E2E Tests ===");

    let mut results = TestResults::new();

    // --- Test: FFA version negotiation ---
    test_ffa_version(&mut results);

    // --- Test: Get our partition ID ---
    let our_id = test_ffa_id_get(&mut results);

    // --- Test: Discover EC partition by Thermal UUID ---
    let ec_id = test_partition_discovery(&mut results);

    // --- Test: Thermal get_temperature ---
    if let (Some(src), Some(dst)) = (our_id, ec_id) {
        test_thermal_get_temperature(&mut results, src, dst);
    }

    // --- Summary and shutdown ---
    let all_passed = results.summary();

    // Shut down QEMU. Exit code depends on pass/fail.
    let status = if all_passed {
        Status::SUCCESS
    } else {
        Status::ABORTED
    };

    runtime::reset(ResetType::SHUTDOWN, status, None);
}

fn test_ffa_version(results: &mut TestResults) {
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

fn test_ffa_id_get(results: &mut TestResults) -> Option<u16> {
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

fn test_partition_discovery(results: &mut TestResults) -> Option<u16> {
    match ffa::ffa_partition_info_get_regs(&THERMAL_UUID) {
        Ok((count, partitions)) => {
            log::debug!("  partition_info: count={}", count);
            for i in 0..count {
                log::debug!(
                    "    [{}] id={:#06x} ctx={} props={:#010x}",
                    i,
                    partitions[i].partition_id,
                    partitions[i].execution_ctx_count,
                    partitions[i].properties,
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
                results.fail("partition_discovery", "no partitions found for thermal UUID");
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

fn test_thermal_get_temperature(results: &mut TestResults, our_id: u16, ec_id: u16) {
    // Build get_temperature request payload.
    // The Thermal service expects a DirectMessagePayload where:
    //   byte 0 = command (EC_THM_GET_TMP = 0x01)
    //   byte 1 = sensor_id (0x00)
    let sensor_id: u8 = 0;
    let payload = DirectMessagePayload::from_iter(
        [EC_THM_GET_TMP, sensor_id]
            .into_iter()
            .chain(core::iter::repeat(0u8).take(14 * 8 - 2)),
    );

    // Build SMC registers directly matching the FF-A spec for DIRECT_REQ2.
    // x0 = FFA_MSG_SEND_DIRECT_REQ2
    // x1 = (source_id << 16) | destination_id   [spec: bits 31:16=source, 15:0=dest]
    // x2 = UUID high half (big-endian u64)
    // x3 = UUID low half (big-endian u64)
    // x4..x17 = payload registers (14 x u64, LE)
    const FFA_MSG_SEND_DIRECT_REQ2: u64 = 0xC400008D;
    const FFA_MSG_SEND_DIRECT_RESP2: u64 = 0xC400008E;
    const FFA_INTERRUPT: u64 = 0x84000062;
    const FFA_YIELD: u64 = 0x8400006C;
    const FFA_RUN: u64 = 0x8400006D;

    let x1 = ((our_id as u64) << 16) | (ec_id as u64);
    let (uuid_high, uuid_low) = THERMAL_UUID.as_u64_pair();
    let x2 = uuid_high.to_be();
    let x3 = uuid_low.to_be();

    // Payload registers: read 14 u64 values from the DirectMessagePayload.
    let payload_regs: alloc::vec::Vec<u64> = payload.registers_iter().collect();

    // Issue the direct request SMC.
    let mut resp = ffa::raw_smc(
        FFA_MSG_SEND_DIRECT_REQ2,
        x1, x2, x3,
        payload_regs[0], payload_regs[1], payload_regs[2], payload_regs[3],
        payload_regs[4], payload_regs[5], payload_regs[6], payload_regs[7],
        payload_regs[8], payload_regs[9], payload_regs[10], payload_regs[11],
        payload_regs[12], payload_regs[13],
    );

    // Retry loop: handle FFA_YIELD / FFA_INTERRUPT by calling FFA_RUN.
    let mut retries = 0;
    while (resp[0] == FFA_YIELD || resp[0] == FFA_INTERRUPT) && retries < 100 {
        log::debug!("  FFA_YIELD/INTERRUPT (x0={:#x}), calling FFA_RUN...", resp[0]);
        let run_arg = ((ec_id as u64) << 16) | 0u64; // target endpoint, vCPU 0
        resp = ffa::raw_smc(FFA_RUN, run_arg, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        retries += 1;
    }

    if resp[0] != FFA_MSG_SEND_DIRECT_RESP2 {
        results.fail("thermal_get_temperature", "unexpected response FID");
        log::error!("  x0={:#018x} (expected DIRECT_RESP2={:#x})", resp[0], FFA_MSG_SEND_DIRECT_RESP2);
        return;
    }

    // Parse the response payload from x4..x17.
    let resp_payload = DirectMessagePayload::from_iter(
        resp[4..18].iter().flat_map(|r| r.to_le_bytes()),
    );

    // Response layout: byte 0..8 = status (i64), byte 8..16 = temperature (u64)
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
