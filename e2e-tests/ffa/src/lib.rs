// Copyright (c) Microsoft Corporation.
// SPDX-License-Identifier: Apache-2.0

//! Thin wrapper around `odp_ffa` for non-secure world UEFI test applications.
//!
//! Re-exports the upstream `odp_ffa` crate and adds functionality not yet
//! implemented there (marked with TODO for future upstreaming).

#![no_std]

// Re-export everything from odp-ffa so consumers can use it directly.
pub use odp_ffa::*;

// TODO(odp-ffa): FFA_PARTITION_INFO_GET_REGS is not yet implemented in odp-ffa.
// Once added upstream, remove this module and re-export from odp_ffa instead.
mod partition_info;
pub use partition_info::{ffa_partition_info_get_regs, PartitionInfo};

// TODO(odp-ffa): Remove once odp_ffa::smc is public.
mod smc;
pub use smc::raw_smc;
