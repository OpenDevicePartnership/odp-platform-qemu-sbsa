// This project is dual-licensed under Apache 2.0 and MIT terms.
// See LICENSE-APACHE and LICENSE-MIT for details.

#![cfg_attr(target_os = "none", no_std)]
#![cfg_attr(target_os = "none", no_main)]
#![deny(clippy::undocumented_unsafe_blocks)]
#![deny(unsafe_op_in_unsafe_fn)]

#[cfg(target_os = "none")]
mod baremetal;
// NOT cfg-gated: host unit tests in `mctp_ping::tests` need to compile under
// the `x86_64-unknown-linux-gnu` target too. Wired into bare-metal `main()`
// in plan 16-03 (call site below); host build doesn't reference it but the
// `#[cfg(test)] mod tests` block keeps it live there.
mod mctp_ping;

#[cfg(not(target_os = "none"))]
fn main() {
    println!("qemu-sp stub");
}

/// TPM CRB MMIO base address.
///
/// Must match the device-region mapping in the SP manifest (`qemu-ec-sp.dts`).
#[cfg(target_os = "none")]
const TPM_CRB_MMIO_BASE: u64 = 0x10000210000;

#[cfg(target_os = "none")]
fn main() -> ! {
    use ec_service_lib::MessageHandler;
    use odp_ffa::Function;

    log::info!("QEMU Secure Partition - build time: {}", env!("BUILD_TIME"));

    let version = odp_ffa::Version::new().exec().unwrap();
    log::info!("FFA version: {}.{}", version.major(), version.minor());

    let tpm_sst = ec_service_lib::services::TpmSst::new();
    let mut tpm = ec_service_lib::services::TpmService::new(tpm_sst);

    // SAFETY: TPM_CRB_MMIO_BASE is mapped as a device region in the SP manifest (qemu-ec-sp.dts).
    unsafe {
        tpm.init(TPM_CRB_MMIO_BASE);
    }

    // Phase 16 — boot-time SP↔EC MCTP ping (D-1, D-5 AMENDED).
    // Construct the SBSA secure-UART driver (base 0x60030000 per qemu-ec-sp.dts) and ping
    // the EC's Battery service. Helper logs MCTP_PING_OK or MCTP_PING_FAIL internally.
    //
    // SAFETY: 0x60030000 is mapped device memory in the SP's address space (DTS partition
    // table, `description = "ec uart"`). No other code in this binary aliases it before
    // this point. `Pl011Uart::new` performs no register writes — TF-A/QEMU initialized
    // BAUD/CR earlier. The braced scope drops `uart` before `run_message_loop()`.
    {
        // SAFETY: 0x60030000 is mapped as a device region in the SP manifest
        // (qemu-ec-sp.dts, `description = "ec uart"`). No other code aliases
        // it before this point. `RawMmio::new` only stores the pointer; no
        // register access happens until the ping helper runs below.
        let mmio = unsafe { qemu_sp_uart::RawMmio::new(0x60030000) };
        let mut uart = qemu_sp_uart::Pl011Uart::new(mmio);
        crate::mctp_ping::send_mctp_ping(&mut uart, /* battery_id = */ 0);
    }

    MessageHandler::new()
        .append(ec_service_lib::services::Thermal::new())
        .append(ec_service_lib::services::FwMgmt::new())
        .append(ec_service_lib::services::Notify::new())
        .append(tpm)
        .run_message_loop()
        .expect("Error in run_message_loop");

    unreachable!()
}
