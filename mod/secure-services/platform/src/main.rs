//! QEMU EC Secure Partition Service entry point.
//!
//! SPDX-License-Identifier: MIT
//!

#![cfg_attr(target_os = "none", no_std)]
#![cfg_attr(target_os = "none", no_main)]
#![deny(clippy::undocumented_unsafe_blocks)]
#![deny(unsafe_op_in_unsafe_fn)]

#[cfg(target_os = "none")]
mod baremetal;

#[cfg(not(target_os = "none"))]
fn main() {
    println!("qemu-sp stub");
}

#[cfg(target_os = "none")]
fn main() -> ! {
    use ec_service_lib::services::TpmServiceStub;
    use ec_service_lib::MessageHandler;
    use odp_ffa::Function;

    log::info!("QEMU Secure Partition - build time: {}", env!("BUILD_TIME"));

    let version = odp_ffa::Version::new().exec().unwrap();
    log::info!("FFA version: {}.{}", version.major(), version.minor());

    let tpm = TpmServiceStub::new();

    MessageHandler::new()
        .append(ec_service_lib::services::Thermal::new())
        .append(ec_service_lib::services::FwMgmt::new())
        .append(ec_service_lib::services::Notify::new())
        .append(tpm)
        .run_message_loop()
        .expect("Error in run_message_loop");

    unreachable!()
}
