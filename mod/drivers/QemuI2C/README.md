---
page_type: sample
description: "A KMDF SPB (I2C) controller driver for the QEMU ODP socket-backed I2C controller."
languages:
- cpp
products:
- windows
- windows-wdk
---

# QEMU I2C Sample Driver

The QemuI2C sample is a KMDF controller driver that conforms to the [simple peripheral bus](https://docs.microsoft.com/windows-hardware/design/component-guidelines/simple-peripheral-bus--spb-) (SPB) device driver interface (DDI) and drives the QEMU "ODP socket-backed I2C controller" (`hw/odp/i2c-controller.c`). It started life as the in-box `SkeletonI2C` sample and has been filled in with the hardware-specific logic for that controller.

It binds to the ACPI device with `_HID` `QEMU0001`, as published by the QEMU SBSA / arm-virt ODP platform firmware. A HID-over-I2C peripheral (`_HID` `QEMU0002`, `_CID` `PNP0C50`) hangs off the controller and is serviced by the in-box `hidi2c.sys` through this driver.

## Hardware interface

The controller exposes a single 0x1000-byte MMIO window with three 32-bit registers and **no interrupt line**, so the driver services transfers by polling:

| Offset | Name   | Notes |
|-------:|--------|-------|
| `0x00` | CTRL   | RX-ready / cmd-done interrupt enables, clear-FIFO (W1C), soft reset (W1) |
| `0x04` | STATUS | RX_RDY (R), NAK / PROTO_ERR / CMD_DONE (R/W1C) |
| `0x08` | DATA   | Write: `(cmd << 8) | byte`; read pops one RX FIFO byte |

Commands are `START` (`(addr7 << 1) | rw`), `STOP`, `RX` (`count - 1`, burst up to 256 bytes) and `TX` (data byte). Each command latches `CMD_DONE` (or `NAK` / `PROTO_ERR`) in STATUS, which the driver polls.

Because the ACPI `_CRS` exposes only memory (no interrupt), the driver runs entirely **polled** at `PASSIVE_LEVEL`:

- The device lock is a `WDFWAITLOCK` (not a spin lock) so the poll loop never spins at `DISPATCH_LEVEL`.
- No `WDFINTERRUPT`, delay timer, or request cancellation is used; SPB serializes I/O and each transfer completes synchronously inside its callback.

## Files

- `qemui2c.h` — controller register map and bit definitions.
- `controller.cpp` — polled transfer engine (`ControllerConfigureForTransfer`, `ControllerTransferData`) and the low-level `QemuI2c*` command helpers.
- `device.cpp` — WDF/SPB plumbing: resource mapping (`OnPrepareHardware`), target connection, and the SPB read/write/sequence callbacks.
- `driver.cpp` — `DriverEntry` / `OnDeviceAdd`.
- `qemui2c.inx` — INF binding to `ACPI\QEMU0001`.
- `qemui2c.asl` — example controller device node for testing.

## Transfer model

For every (sub)transfer the driver issues a (repeated) `START` carrying the direction bit, transfers the data phase (TX byte-by-byte, or RX in bursts of up to 256 bytes drained from the FIFO), and issues `STOP` when the SPB sequence position indicates the end. A combined write-then-read (the common HID-over-I2C pattern) is expressed as a two-transfer SPB sequence and produces `START(W) ... repeated-START(R) ... STOP` framing.

Error mapping:

- NAK while addressing -> `STATUS_NO_SUCH_DEVICE`.
- NAK during a write -> short (successful) transfer; the client sees the byte count actually accepted.
- Protocol error -> `STATUS_IO_DEVICE_ERROR`.
- Command never completes within the poll timeout -> `STATUS_IO_TIMEOUT`.

## Building and installing

Build for ARM64 (the QEMU SBSA / arm-virt target) or x64 with the WDK/EWDK:

```
msbuild qemui2c.sln /p:Configuration=Release /p:Platform=ARM64
```

The driver package (`qemui2c.sys`, `qemui2c.inf`, `qemui2c.cat`) can then be test-signed and staged into an offline image with `dism /image:<path> /add-driver`.
