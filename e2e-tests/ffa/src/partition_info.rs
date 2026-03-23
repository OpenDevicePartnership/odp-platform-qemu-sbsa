// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: Apache-2.0

//! TODO(odp-ffa): FFA_PARTITION_INFO_GET_REGS implementation.
//!
//! This should be upstreamed into the `odp-ffa` crate as a proper `Function`
//! impl, similar to `Version`, `IdGet`, etc. For now we implement it here
//! using raw SMC inline assembly since `odp_ffa::smc` is not public.

use uuid::Uuid;

const FFA_PARTITION_INFO_GET_REGS: u64 = 0xC400008B;
const FFA_SUCCESS_64: u64 = 0xC4000061;

/// Information about a discovered partition.
#[derive(Debug, Clone, Copy)]
pub struct PartitionInfo {
    pub partition_id: u16,
    pub execution_ctx_count: u16,
    pub properties: u32,
}

/// Discover partitions that implement a given service UUID.
///
/// Uses FFA_PARTITION_INFO_GET_REGS (register-based partition info query).
/// Returns up to 4 matching partition descriptors.
///
/// TODO(odp-ffa): This uses raw SMC assembly because `odp_ffa::smc::ffa_smc`
/// is pub(crate). Once this is upstreamed, it should use the `Function` trait.
pub fn ffa_partition_info_get_regs(uuid: &Uuid) -> Result<(usize, [PartitionInfo; 4]), odp_ffa::Error> {
    // Pack UUID into x1/x2 using the same convention as DirectMessage:
    // odp-ffa uses Uuid::as_u64_pair() -> (high, low), then .to_be() for each.
    let (uuid_high, uuid_low) = uuid.as_u64_pair();
    let x1 = uuid_high.to_be();
    let x2 = uuid_low.to_be();

    let result: [u64; 18] = raw_smc(
        FFA_PARTITION_INFO_GET_REGS, x1, x2, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    );

    log::debug!("PART_INFO_GET_REGS input: x1={:#018x} x2={:#018x}", x1, x2);
    log::debug!("PART_INFO_GET_REGS output: x0={:#018x} x2={:#018x} x3={:#018x}",
        result[0], result[2], result[3]);

    if result[0] != FFA_SUCCESS_64 {
        // Try to parse as FFA error
        let fid = odp_ffa::FunctionId::try_from(result[0])
            .map_err(|e| odp_ffa::Error::InvalidFunctionId(e.number))?;
        return Err(odp_ffa::Error::UnexpectedFunctionId(fid));
    }

    // x2 contains metadata:
    //   [63:48] = descriptor size
    //   [47:32] = current index
    //   [31:16] = last index (total_entries - 1)
    //   [15:0]  = start index
    let meta = result[2];
    let last_idx = ((meta >> 16) & 0xFFFF) as usize;
    let count = (last_idx + 1).min(4);

    // Partition descriptors are packed 3 registers per entry starting at x3 (result[3]).
    // Each descriptor: reg+0 = (properties[63:32] | exec_ctx[31:16] | part_id[15:0])
    //                  reg+1 = UUID low, reg+2 = UUID high
    let regs = &result[3..];

    let mut infos = [PartitionInfo {
        partition_id: 0,
        execution_ctx_count: 0,
        properties: 0,
    }; 4];

    for i in 0..count {
        let base = i * 3;
        if base >= regs.len() {
            break;
        }
        let r0 = regs[base];
        infos[i] = PartitionInfo {
            partition_id: (r0 & 0xFFFF) as u16,
            execution_ctx_count: ((r0 >> 16) & 0xFFFF) as u16,
            properties: ((r0 >> 32) & 0xFFFFFFFF) as u32,
        };
    }

    Ok((count, infos))
}

use crate::smc::raw_smc;
