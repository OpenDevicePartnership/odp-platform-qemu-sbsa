/*++

Copyright (c) Microsoft Corporation.  All rights reserved.

Module Name: 

    qemui2c.h

Abstract:

    This module contains the controller-specific type 
    definitions for the QEMU "ODP socket-backed I2C controller"
    hardware (QEMU _HID "QEMU0001").

    The hardware interface mirrors hw/odp/i2c-controller.c from
    the QEMU ODP tree: three 32-bit memory-mapped registers
    (CTRL, STATUS, DATA) inside a 0x1000-byte window, driven as an
    I2C master via START / STOP / TX / RX commands and signalled
    back through latched status bits.

Environment:

    kernel-mode only

Revision History:

--*/

//
// Includes for hardware register definitions.
//

#ifndef _QEMUI2C_H_
#define _QEMUI2C_H_

#include "hw.h"

//
// QEMU I2C controller register map. All registers are 32-bit and the
// controller only supports 32-bit (DWORD) accesses. Register offsets:
//
//   0x00  CTRL    (R/W)
//   0x04  STATUS  (R/W1C for the latched bits)
//   0x08  DATA    (W: command+byte, R: pop one RX FIFO byte)
//

typedef struct QEMUI2C_REGISTERS
{
    __declspec(align(4)) HWREG<ULONG>  Ctrl;     // 0x00
    __declspec(align(4)) HWREG<ULONG>  Status;   // 0x04
    __declspec(align(4)) HWREG<ULONG>  Data;     // 0x08
}
QEMUI2C_REGISTERS, *PQEMUI2C_REGISTERS;

//
// CTRL register bits.
//

#define QEMU_I2C_CTRL_RX_RDY_IE     (1u << 0)   // RX-ready interrupt enable     (R/W)
#define QEMU_I2C_CTRL_CMD_DONE_IE   (1u << 1)   // CMD-complete interrupt enable (R/W)
#define QEMU_I2C_CTRL_CLEAR_FIFO    (1u << 2)   // clear RX FIFO                 (W1C)
#define QEMU_I2C_CTRL_RESET         (1u << 3)   // soft reset, self-clearing     (W1)
#define QEMU_I2C_CTRL_IE_MASK       (QEMU_I2C_CTRL_RX_RDY_IE | QEMU_I2C_CTRL_CMD_DONE_IE)

//
// STATUS register bits.
//

#define QEMU_I2C_STATUS_RX_RDY      (1u << 0)   // RX FIFO not empty             (R)
#define QEMU_I2C_STATUS_NAK         (1u << 1)   // target NAKed / link dropped   (R/W1C)
#define QEMU_I2C_STATUS_PROTO_ERR   (1u << 2)   // illegal command ordering      (R/W1C)
#define QEMU_I2C_STATUS_CMD_DONE    (1u << 3)   // command completed             (R/W1C)
#define QEMU_I2C_STATUS_W1C_MASK    (QEMU_I2C_STATUS_NAK | QEMU_I2C_STATUS_PROTO_ERR | QEMU_I2C_STATUS_CMD_DONE)

//
// DATA register write format: data byte in bits [7:0], command in bits [9:8].
//

#define QEMU_I2C_DATA_DATA_MASK     0xFFu
#define QEMU_I2C_DATA_CMD_SHIFT     8
#define QEMU_I2C_DATA_CMD_MASK      0x3u

#define QEMU_I2C_CMD_START          0x0u        // data = (addr7 << 1) | rwbit
#define QEMU_I2C_CMD_STOP           0x1u
#define QEMU_I2C_CMD_RX             0x2u        // data = (count - 1), burst read
#define QEMU_I2C_CMD_TX             0x3u        // data = byte to transmit

//
// Build a DATA register write word from a command and a byte.
//

#define QEMU_I2C_MAKE_DATA(cmd, byte) \
    ((((ULONG)(cmd) & QEMU_I2C_DATA_CMD_MASK) << QEMU_I2C_DATA_CMD_SHIFT) | \
     ((ULONG)(byte) & QEMU_I2C_DATA_DATA_MASK))

//
// The QEMU controller RX FIFO holds up to 256 bytes, and a single RX
// command can request at most 256 bytes (count-1 is an 8-bit field).
//

#define QEMU_I2C_RX_FIFO_SIZE       256

//
// Maximum transfer length accepted from a peripheral driver. Larger
// transfers are split into multiple RX bursts / TX bytes by the
// controller logic, so this is just a sane upper bound.
//

#define SI2C_MAX_TRANSFER_LENGTH    0x00001000

//
// Maximum time (in microseconds) to poll for a command to complete
// before giving up and failing the transfer, and the stall granularity
// between status reads.
//

#define QEMU_I2C_POLL_TIMEOUT_US    1000000     // 1 second
#define QEMU_I2C_POLL_INTERVAL_US   10          // stall per poll iteration


//
// Register evaluation functions.
//

FORCEINLINE
bool
TestAnyBits(
    _In_ ULONG V1,
    _In_ ULONG V2
    )
{
    return (V1 & V2) != 0;
}

FORCEINLINE
bool
TestAllBits(
    _In_ ULONG V1,
    _In_ ULONG V2
    )
{
    return ((V1 & V2) == V2);
}

#endif
