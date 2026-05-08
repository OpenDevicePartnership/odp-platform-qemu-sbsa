//! Raw SMC #0 helper.
//!
//! SPDX-License-Identifier: MIT
//!
//! TODO(odp-ffa): Remove once `odp_ffa::smc` is public or all needed
//! FF-A calls are implemented as `Function` impls upstream.

/// Issue an SMC #0 with all 18 GP registers (x0–x17).
#[inline(always)]
#[allow(clippy::too_many_arguments)]
pub fn raw_smc(
    x0: u64,
    x1: u64,
    x2: u64,
    x3: u64,
    x4: u64,
    x5: u64,
    x6: u64,
    x7: u64,
    x8: u64,
    x9: u64,
    x10: u64,
    x11: u64,
    x12: u64,
    x13: u64,
    x14: u64,
    x15: u64,
    x16: u64,
    x17: u64,
) -> [u64; 18] {
    let mut result = [0u64; 18];
    unsafe {
        core::arch::asm!(
            "smc #0",
            inout("x0") x0 => result[0],
            inout("x1") x1 => result[1],
            inout("x2") x2 => result[2],
            inout("x3") x3 => result[3],
            inout("x4") x4 => result[4],
            inout("x5") x5 => result[5],
            inout("x6") x6 => result[6],
            inout("x7") x7 => result[7],
            inout("x8") x8 => result[8],
            inout("x9") x9 => result[9],
            inout("x10") x10 => result[10],
            inout("x11") x11 => result[11],
            inout("x12") x12 => result[12],
            inout("x13") x13 => result[13],
            inout("x14") x14 => result[14],
            inout("x15") x15 => result[15],
            inout("x16") x16 => result[16],
            inout("x17") x17 => result[17],
            options(nostack),
        );
    }
    result
}
