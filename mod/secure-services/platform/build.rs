//! @file build.rs
//!
//! Build script for the QEMU EC Secure Partition Service
//!
//! Copyright (c) Microsoft Corporation.
//! SPDX-License-Identifier: Apache-2.0

fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").unwrap() == "none" {
        println!(
            "cargo:rustc-env=BUILD_TIME={}",
            chrono::Utc::now().to_rfc3339()
        );
        println!("cargo:rustc-link-arg=-Tlinker/image.ld");
        println!("cargo:rustc-link-arg=-Tlinker/qemu.ld");
        println!("cargo:rerun-if-changed=linker/qemu.ld");
        println!("cargo:rerun-if-changed=linker/image.ld");
    }
}
