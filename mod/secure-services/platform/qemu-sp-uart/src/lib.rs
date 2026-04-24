#![no_std]
#![deny(unsafe_op_in_unsafe_fn)]
#![deny(clippy::undocumented_unsafe_blocks)]

//! Hand-rolled blocking PL011 UART driver for the QEMU SBSA secure partition.
//!
//! Polled TX (blocks while TXFF set), polled RX with a busy-wait iteration-count
//! bound (NOT wall-clock — per Phase 14 D-4). MMIO is fronted by the [`Mmio`]
//! trait so the bit-twiddling logic is host-testable with a mock backend.
//!
//! See `.planning/phases/14-sp-uart-driver-pl011/14-CONTEXT.md` for register
//! layout, decision rationale, and the QEMU SBSA `serial_hd(1)` mapping.

/// Minimal MMIO abstraction. Real hardware impl uses
/// `core::ptr::{read,write}_volatile`; host tests use a mock backend.
/// Offsets are byte offsets from the device base.
pub trait Mmio {
    /// Read a `u32` at byte offset `off` from the base.
    ///
    /// # Safety
    /// Caller guarantees the offset addresses a valid device register.
    unsafe fn read32(&self, off: usize) -> u32;
    /// Read a `u8` at byte offset `off`.
    ///
    /// # Safety
    /// See [`Mmio::read32`].
    unsafe fn read8(&self, off: usize) -> u8;
    /// Write a `u8` at byte offset `off`.
    ///
    /// # Safety
    /// See [`Mmio::read32`]. Caller must ensure the offset is writable.
    unsafe fn write8(&mut self, off: usize, val: u8);
}

/// Real hardware backend. Wraps a raw MMIO base address.
pub struct RawMmio {
    base: *mut u8,
}

// SAFETY: `RawMmio` holds a raw pointer to a mapped device region. The Send/Sync
// negative auto-impl from the raw pointer is intentional — callers wrapping it in
// `Pl011Uart` are expected to use it from a single executor context (the SP main
// loop). We do NOT manually impl `Send`/`Sync`.

impl RawMmio {
    /// Wrap a raw MMIO base address.
    ///
    /// # Safety
    /// `base` must point to a mapped PL011 device region of at least `0x40`
    /// bytes, matching the SP DTS device-region attributes (R/W, device memory).
    pub unsafe fn new(base: usize) -> Self {
        Self {
            base: base as *mut u8,
        }
    }
}

impl Mmio for RawMmio {
    unsafe fn read32(&self, off: usize) -> u32 {
        // SAFETY: precondition of `RawMmio::new` — `base` is a mapped device region
        // and `off` is within bounds of that region.
        unsafe { core::ptr::read_volatile(self.base.add(off) as *const u32) }
    }
    unsafe fn read8(&self, off: usize) -> u8 {
        // SAFETY: same precondition as `read32`.
        unsafe { core::ptr::read_volatile(self.base.add(off)) }
    }
    unsafe fn write8(&mut self, off: usize, val: u8) {
        // SAFETY: same precondition as `read32`; `off` must be writable.
        unsafe { core::ptr::write_volatile(self.base.add(off), val) }
    }
}

// PL011 register offsets (relative to base, confirmed Phase 12 VERDICT).
const UARTDR: usize = 0x000;
const UARTFR: usize = 0x018;
// PL011 flag-register bits.
const FR_RXFE: u32 = 1 << 4; // RX FIFO empty
const FR_TXFF: u32 = 1 << 5; // TX FIFO full
// (BUSY bit 3 not currently used — Phase 12 spike showed BUSY-spinning is
// unnecessary on QEMU.)

/// PL011 driver errors.
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum Error {
    /// Bounded RX poll exhausted its iteration budget without seeing a byte.
    Timeout,
}

/// Default RX iteration budget. Tuned conservatively to fail well before the
/// outer `make e2e-test` watchdog (per UD-02). Wall-clock duration varies by
/// CPU/build profile (Phase 14 D-4 accepts this).
///
/// **Practical note (Plan 14-02 finding):** on QEMU SBSA this budget exhausts
/// in milliseconds — far less than the seconds an EC round-trip actually needs.
/// Callers expecting an SP↔EC reply (e.g. MCTP relay) MUST pass a larger
/// `max_iters` to [`Pl011Uart::read_byte_timeout`] (`u32::MAX` is a safe
/// upper bound; it caps at a few seconds of QEMU wall-clock). The default
/// is appropriate for unit-test "no-byte-arrived" assertions and host fakes.
pub const DEFAULT_RX_TIMEOUT_ITERS: u32 = 1_000_000;

/// Blocking PL011 UART driver. Generic over the [`Mmio`] backend.
pub struct Pl011Uart<M: Mmio> {
    mmio: M,
}

impl<M: Mmio> Pl011Uart<M> {
    /// Wrap an MMIO backend. Does NOT touch UARTCR / UARTLCR_H — TF-A and QEMU
    /// init are assumed (Phase 14 D-4: no BAUD reconfigure).
    pub const fn new(mmio: M) -> Self {
        Self { mmio }
    }

    /// Borrow the underlying MMIO backend (test-only convenience).
    #[cfg(test)]
    fn mmio(&self) -> &M {
        &self.mmio
    }

    /// Blocking write of one byte. Polls `UARTFR.TXFF` until clear, then writes
    /// `UARTDR`.
    pub fn write_byte(&mut self, b: u8) {
        // SAFETY: `UARTFR` / `UARTDR` are in the device region passed to
        // `RawMmio::new` (or are the mock backend's tracked offsets in tests).
        // The bounded poll loop reads only; the final write goes to a known
        // writable offset (`UARTDR`).
        unsafe {
            while self.mmio.read32(UARTFR) & FR_TXFF != 0 {
                core::hint::spin_loop();
            }
            self.mmio.write8(UARTDR, b);
        }
    }

    /// Blocking write of a byte slice. Each byte goes through TXFF polling.
    pub fn write_bytes(&mut self, bytes: &[u8]) {
        for &b in bytes {
            self.write_byte(b);
        }
    }

    /// Polled read with a bounded busy-wait iteration budget (Phase 14 D-4).
    /// Returns the byte on success, or `Err(Error::Timeout)` if `max_iters`
    /// `UARTFR` reads all observe `RXFE = 1`.
    pub fn read_byte_timeout(&mut self, max_iters: u32) -> Result<u8, Error> {
        for _ in 0..max_iters {
            // SAFETY: see `write_byte`. Loop reads only.
            let fr = unsafe { self.mmio.read32(UARTFR) };
            if fr & FR_RXFE == 0 {
                // SAFETY: `RXFE` clear ⇒ at least one byte in the RX FIFO.
                return Ok(unsafe { self.mmio.read8(UARTDR) });
            }
            core::hint::spin_loop();
        }
        Err(Error::Timeout)
    }
}

// ---------------------------------------------------------------------------
// Host-side tests (UD-03 + ROADMAP success criterion #4).
// `MockMmio` lives entirely under `#[cfg(test)]` — it intentionally does NOT
// exist in the `aarch64-unknown-none` binary, preserving the no-alloc runtime.
// ---------------------------------------------------------------------------

#[cfg(test)]
extern crate std;

#[cfg(test)]
mod tests {
    use super::*;
    use core::cell::Cell;
    use std::collections::VecDeque;
    use std::vec;
    use std::vec::Vec;

    /// Scripted MMIO backend.
    ///
    /// `fr_script` is a queue of `UARTFR` values; each `read32(UARTFR)` pops
    /// one (returning `fr_default` once exhausted). `dr_rx_byte` is what
    /// `read8(UARTDR)` returns. `dr_tx_log` records every `write8(UARTDR, …)`
    /// in order.
    struct MockMmio {
        fr_script: std::cell::RefCell<VecDeque<u32>>,
        fr_default: u32,
        fr_read_count: Cell<u32>,
        dr_rx_byte: u8,
        dr_tx_log: std::cell::RefCell<Vec<u8>>,
    }

    impl MockMmio {
        fn new(fr_default: u32, dr_rx_byte: u8) -> Self {
            Self {
                fr_script: std::cell::RefCell::new(VecDeque::new()),
                fr_default,
                fr_read_count: Cell::new(0),
                dr_rx_byte,
                dr_tx_log: std::cell::RefCell::new(Vec::new()),
            }
        }
        fn push_fr(&mut self, v: u32) {
            self.fr_script.borrow_mut().push_back(v);
        }
        fn fr_read_count(&self) -> u32 {
            self.fr_read_count.get()
        }
        fn dr_tx_log(&self) -> Vec<u8> {
            self.dr_tx_log.borrow().clone()
        }
    }

    impl Mmio for MockMmio {
        unsafe fn read32(&self, off: usize) -> u32 {
            assert_eq!(off, UARTFR, "MockMmio only models UARTFR for read32");
            self.fr_read_count.set(self.fr_read_count.get() + 1);
            self.fr_script
                .borrow_mut()
                .pop_front()
                .unwrap_or(self.fr_default)
        }
        unsafe fn read8(&self, off: usize) -> u8 {
            assert_eq!(off, UARTDR);
            self.dr_rx_byte
        }
        unsafe fn write8(&mut self, off: usize, val: u8) {
            assert_eq!(off, UARTDR);
            self.dr_tx_log.borrow_mut().push(val);
        }
    }

    #[test]
    fn write_byte_polls_txff_then_writes_dr() {
        let mut mock = MockMmio::new(0, 0);
        mock.push_fr(FR_TXFF); // first poll: TX full
        mock.push_fr(FR_TXFF); // second poll: still full
        mock.push_fr(0); // third poll: clear → write
        let mut uart = Pl011Uart::new(mock);
        uart.write_byte(0x42);
        assert_eq!(uart.mmio().dr_tx_log(), vec![0x42]);
        assert_eq!(uart.mmio().fr_read_count(), 3);
    }

    #[test]
    fn read_byte_returns_when_rxfe_clears() {
        let mut mock = MockMmio::new(0, 0xA5);
        mock.push_fr(FR_RXFE); // empty
        mock.push_fr(FR_RXFE); // empty
        mock.push_fr(0); // byte ready
        let mut uart = Pl011Uart::new(mock);
        assert_eq!(uart.read_byte_timeout(10_000), Ok(0xA5));
        assert_eq!(uart.mmio().fr_read_count(), 3);
    }

    #[test]
    fn read_byte_timeout_returns_err_when_silent() {
        // RXFE stuck high forever — UD-02 / ROADMAP criterion #2.
        let mock = MockMmio::new(FR_RXFE, 0);
        let mut uart = Pl011Uart::new(mock);
        assert_eq!(uart.read_byte_timeout(1_000), Err(Error::Timeout));
        let n = uart.mmio().fr_read_count();
        assert!(n >= 1_000, "expected >= 1000 polls, got {n}");
        assert!(n <= 1_010, "should bail within budget, got {n}");
    }

    #[test]
    fn write_bytes_drains_fifo() {
        let mock = MockMmio::new(0, 0);
        let mut uart = Pl011Uart::new(mock);
        uart.write_bytes(b"hi");
        assert_eq!(uart.mmio().dr_tx_log(), vec![b'h', b'i']);
    }

    #[test]
    fn read_byte_zero_iters_immediate_timeout() {
        let mock = MockMmio::new(FR_RXFE, 0);
        let mut uart = Pl011Uart::new(mock);
        assert_eq!(uart.read_byte_timeout(0), Err(Error::Timeout));
        assert_eq!(uart.mmio().fr_read_count(), 0);
    }
}
