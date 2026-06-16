/*++

Copyright (c) Microsoft Corporation.  All rights reserved.

Module Name: 

    controller.cpp

Abstract:

    This module contains the controller-specific functions
    for the QEMU "ODP socket-backed I2C controller".

    The controller is driven by polling its STATUS register;
    the QEMU device exposes no interrupt line in its ACPI _CRS.
    All transfers complete synchronously inside the SPB
    read/write/sequence callbacks at PASSIVE_LEVEL.

    Hardware command model (see hw/odp/i2c-controller.c):
      - Write DATA = (CMD_START << 8) | (addr7 << 1 | rw) to address a
        target. The controller raises CMD_DONE when the target ACKs (or
        NAK on no response).
      - Write DATA = (CMD_TX << 8) | byte to transmit a byte; CMD_DONE on
        ACK, NAK on data NAK.
      - Write DATA = (CMD_RX << 8) | (count - 1) to read a burst of up to
        256 bytes; CMD_DONE when the whole burst has arrived in the RX
        FIFO. Read DATA to pop bytes while STATUS_RX_RDY is set.
      - Write DATA = (CMD_STOP << 8) to release the bus; CMD_DONE follows.

Environment:

    kernel-mode only

Revision History:

--*/

#include "internal.h"
#include "controller.h"
#include "device.h"

#include "controller.tmh"

const PBC_TRANSFER_SETTINGS g_TransferSettings[] = 
{
    // Bus condition        IsStart  IsEnd
    {BusConditionDontCare,  FALSE,   FALSE}, // SpbRequestSequencePositionInvalid
    {BusConditionFree,      TRUE,    TRUE},  // SpbRequestSequencePositionSingle
    {BusConditionFree,      TRUE,    FALSE}, // SpbRequestSequencePositionFirst
    {BusConditionBusy,      FALSE,   FALSE}, // SpbRequestSequencePositionContinue
    {BusConditionBusy,      FALSE,   TRUE}   // SpbRequestSequencePositionLast
};

/////////////////////////////////////////////////
//
// Low-level polled hardware helpers.
//
/////////////////////////////////////////////////

_IRQL_requires_max_(PASSIVE_LEVEL)
static
VOID
QemuI2cStall(
    _In_ ULONG Microseconds
    )
/*++

  Routine Description:

    Busy-waits (for short intervals) or sleeps (for longer intervals) at
    PASSIVE_LEVEL for the requested number of microseconds.

--*/
{
    if (Microseconds == 0)
    {
        return;
    }

    if (Microseconds < 100)
    {
        KeStallExecutionProcessor(Microseconds);
    }
    else
    {
        LARGE_INTEGER interval;

        //
        // Relative timeout in 100ns units (negative).
        //

        interval.QuadPart = -((LONGLONG)Microseconds * 10);
        KeDelayExecutionThread(KernelMode, FALSE, &interval);
    }
}

_IRQL_requires_max_(PASSIVE_LEVEL)
static
NTSTATUS
QemuI2cPollStatus(
    _In_  PPBC_DEVICE  pDevice,
    _In_  ULONG        WaitBits,
    _Out_ PULONG       pStatus
    )
/*++

  Routine Description:

    Polls the STATUS register until any of WaitBits is set or a timeout
    elapses. Spins for the first millisecond (fast path for a responsive
    controller) and then sleeps in 1 ms increments to avoid burning the
    CPU on the (rare) slow path.

  Return Value:

    STATUS_SUCCESS if one of WaitBits was observed, STATUS_IO_TIMEOUT
    otherwise. *pStatus always receives the last STATUS value read.

--*/
{
    ULONG elapsedUs = 0;
    ULONG status;

    for (;;)
    {
        status = pDevice->pRegisters->Status.Read();

        if ((status & WaitBits) != 0)
        {
            *pStatus = status;
            return STATUS_SUCCESS;
        }

        if (elapsedUs >= QEMU_I2C_POLL_TIMEOUT_US)
        {
            *pStatus = status;
            return STATUS_IO_TIMEOUT;
        }

        if (elapsedUs < 1000)
        {
            KeStallExecutionProcessor(QEMU_I2C_POLL_INTERVAL_US);
            elapsedUs += QEMU_I2C_POLL_INTERVAL_US;
        }
        else
        {
            QemuI2cStall(1000);
            elapsedUs += 1000;
        }
    }
}

_IRQL_requires_max_(PASSIVE_LEVEL)
static
NTSTATUS
QemuI2cIssueCommand(
    _In_  PPBC_DEVICE  pDevice,
    _In_  ULONG        Command,
    _In_  UCHAR        Data,
    _Out_ PULONG       pStatus
    )
/*++

  Routine Description:

    Writes a command word to the DATA register and waits for the command
    to complete (CMD_DONE), or for a NAK / protocol error. The latched
    status bits are write-1-to-clear acknowledged before returning so the
    next command starts from a clean state.

  Return Value:

    STATUS_SUCCESS if the command completed (caller must inspect *pStatus
    for NAK / PROTO_ERR), STATUS_IO_TIMEOUT if it never completed.

--*/
{
    NTSTATUS status;
    ULONG hwStatus;

    pDevice->pRegisters->Data.Write(QEMU_I2C_MAKE_DATA(Command, Data));

    status = QemuI2cPollStatus(
        pDevice,
        QEMU_I2C_STATUS_CMD_DONE | QEMU_I2C_STATUS_NAK | QEMU_I2C_STATUS_PROTO_ERR,
        &hwStatus);

    //
    // Acknowledge (write-1-to-clear) the latched status bits.
    //

    if ((hwStatus & QEMU_I2C_STATUS_W1C_MASK) != 0)
    {
        pDevice->pRegisters->Status.Write(hwStatus & QEMU_I2C_STATUS_W1C_MASK);
    }

    *pStatus = hwStatus;
    return status;
}

_IRQL_requires_max_(PASSIVE_LEVEL)
static
NTSTATUS
QemuI2cStart(
    _In_  PPBC_DEVICE  pDevice,
    _In_  UCHAR        Address7Bit,
    _In_  BOOLEAN      Read,
    _Out_ PULONG       pStatus
    )
{
    UCHAR addressByte = (UCHAR)((Address7Bit << 1) | (Read ? 0x01 : 0x00));
    return QemuI2cIssueCommand(pDevice, QEMU_I2C_CMD_START, addressByte, pStatus);
}

/////////////////////////////////////////////////
//
// Controller initialization.
//
/////////////////////////////////////////////////

VOID
ControllerInitialize(
    _In_  PPBC_DEVICE  pDevice
    )
/*++
 
  Routine Description:

    This routine initializes the controller hardware.

--*/
{
    FuncEntry(TRACE_FLAG_PBCLOADING);
                        
    NT_ASSERT(pDevice != NULL);

    if (pDevice->pRegisters != NULL)
    {
        //
        // Soft reset the controller state machine and RX FIFO, clear any
        // latched status, and leave interrupts disabled (polled driver).
        //

        pDevice->pRegisters->Ctrl.Write(QEMU_I2C_CTRL_RESET);
        pDevice->pRegisters->Ctrl.Write(QEMU_I2C_CTRL_CLEAR_FIFO);
        pDevice->pRegisters->Status.Write(QEMU_I2C_STATUS_W1C_MASK);
        pDevice->pRegisters->Ctrl.Write(0);
    }

    FuncExit(TRACE_FLAG_PBCLOADING);
}

VOID
ControllerUninitialize(
    _In_  PPBC_DEVICE  pDevice
    )
/*++
 
  Routine Description:

    This routine uninitializes the controller hardware.

--*/
{
    FuncEntry(TRACE_FLAG_PBCLOADING);

    NT_ASSERT(pDevice != NULL);

    if (pDevice->pRegisters != NULL)
    {
        //
        // Disable interrupts and quiesce the controller.
        //

        pDevice->pRegisters->Ctrl.Write(QEMU_I2C_CTRL_RESET);
        pDevice->pRegisters->Ctrl.Write(0);
    }

    FuncExit(TRACE_FLAG_PBCLOADING);
}

/////////////////////////////////////////////////
//
// Transfer handling (polled).
//
/////////////////////////////////////////////////

VOID
ControllerConfigureForTransfer(
    _In_  PPBC_DEVICE   pDevice,
    _In_  PPBC_REQUEST  pRequest
    )
/*++
 
  Routine Description:

    This routine performs an entire (sub)transfer synchronously by
    polling the controller, then completes it. Because the controller is
    polled there is no asynchronous interrupt phase.

  Arguments:

    pDevice - a pointer to the PBC device context
    pRequest - a pointer to the PBC request context

  Return Value:

    None. The request transfer is completed via ControllerCompleteTransfer.

--*/
{
    FuncEntry(TRACE_FLAG_TRANSFER);

    NTSTATUS status;
    ULONG hwStatus = 0;
    PPBC_TARGET pTarget;
    UCHAR address7Bit;
    BOOLEAN read;

    NT_ASSERT(pDevice  != NULL);
    NT_ASSERT(pRequest != NULL);

    pTarget = pDevice->pCurrentTarget;
    NT_ASSERT(pTarget != NULL);

    //
    // Initialize request context for transfer.
    //

    pRequest->Settings = g_TransferSettings[pRequest->SequencePosition];
    pRequest->Status = STATUS_SUCCESS;
    pDevice->InterruptStatus = 0;

    //
    // The QEMU controller only supports 7-bit addressing.
    //

    if (pTarget->Settings.AddressMode != AddressMode7Bit)
    {
        Trace(
            TRACE_LEVEL_ERROR,
            TRACE_FLAG_TRANSFER,
            "10-bit addressing is not supported by the QEMU I2C controller "
            "(WDFDEVICE %p)",
            pDevice->FxDevice);

        pRequest->Status = STATUS_NOT_SUPPORTED;
        pRequest->Information = 0;
        ControllerCompleteTransfer(pDevice, pRequest, TRUE);
        goto exit;
    }

    address7Bit = (UCHAR)(pTarget->Settings.Address & 0x7F);
    read = (pRequest->Direction == SpbTransferDirectionFromDevice);

    Trace(
        TRACE_LEVEL_VERBOSE,
        TRACE_FLAG_TRANSFER,
        "Controller starting %s of %Iu bytes to address 0x%lx "
        "(SPBREQUEST %p, WDFDEVICE %p, IsStart=%d, IsEnd=%d)",
        read ? "read" : "write",
        pRequest->Length,
        pTarget->Settings.Address,
        pRequest->SpbRequest,
        pDevice->FxDevice,
        pRequest->Settings.IsStart,
        pRequest->Settings.IsEnd);

    //
    // Address the target with a (repeated) START carrying the direction
    // bit for this transfer. The QEMU controller accepts a START both
    // from the idle bus (Single / First) and from a bus that is already
    // open (repeated START for Continue / Last and direction changes).
    //

    status = QemuI2cStart(pDevice, address7Bit, read, &hwStatus);

    if (!NT_SUCCESS(status))
    {
        Trace(
            TRACE_LEVEL_ERROR,
            TRACE_FLAG_TRANSFER,
            "Timeout addressing target 0x%lx (WDFDEVICE %p) - %!STATUS!",
            pTarget->Settings.Address,
            pDevice->FxDevice,
            status);

        pRequest->Status = STATUS_IO_TIMEOUT;
        pRequest->Information = 0;
        ControllerCompleteTransfer(pDevice, pRequest, TRUE);
        goto exit;
    }

    if (TestAnyBits(hwStatus, QEMU_I2C_STATUS_PROTO_ERR))
    {
        pRequest->Status = STATUS_IO_DEVICE_ERROR;
        pRequest->Information = 0;
        ControllerCompleteTransfer(pDevice, pRequest, TRUE);
        goto exit;
    }

    if (TestAnyBits(hwStatus, QEMU_I2C_STATUS_NAK))
    {
        //
        // An address NACK indicates that no device responded at this
        // address.
        //

        Trace(
            TRACE_LEVEL_ERROR,
            TRACE_FLAG_TRANSFER,
            "NACK addressing target 0x%lx (WDFDEVICE %p)",
            pTarget->Settings.Address,
            pDevice->FxDevice);

        pRequest->Status = STATUS_NO_SUCH_DEVICE;
        pRequest->Information = 0;
        ControllerCompleteTransfer(pDevice, pRequest, TRUE);
        goto exit;
    }

    //
    // Transfer the data phase (TX or RX).
    //

    status = ControllerTransferData(pDevice, pRequest);

    if (!NT_SUCCESS(status))
    {
        Trace(
            TRACE_LEVEL_ERROR,
            TRACE_FLAG_TRANSFER,
            "Error transferring data for target 0x%lx (WDFDEVICE %p) - %!STATUS!",
            pTarget->Settings.Address,
            pDevice->FxDevice,
            status);

        pRequest->Status = status;
        ControllerCompleteTransfer(pDevice, pRequest, TRUE);
        goto exit;
    }

    //
    // Issue a STOP to release the bus if this is the end of the
    // (sequence of) transfer(s).
    //

    if (pRequest->Settings.IsEnd)
    {
        status = QemuI2cIssueCommand(pDevice, QEMU_I2C_CMD_STOP, 0, &hwStatus);

        if (!NT_SUCCESS(status))
        {
            Trace(
                TRACE_LEVEL_ERROR,
                TRACE_FLAG_TRANSFER,
                "Timeout issuing STOP for target 0x%lx (WDFDEVICE %p) - %!STATUS!",
                pTarget->Settings.Address,
                pDevice->FxDevice,
                status);

            pRequest->Status = STATUS_IO_TIMEOUT;
            ControllerCompleteTransfer(pDevice, pRequest, TRUE);
            goto exit;
        }
    }

    //
    // The (sub)transfer succeeded. Complete it and advance the sequence.
    //

    ControllerCompleteTransfer(pDevice, pRequest, FALSE);

exit:

    FuncExit(TRACE_FLAG_TRANSFER);
}

NTSTATUS
ControllerTransferData(
    _In_  PPBC_DEVICE   pDevice,
    _In_  PPBC_REQUEST  pRequest
    )
/*++
 
  Routine Description:

    This routine transfers the data phase of a transfer to or from the
    device. The bus has already been addressed with a START.

  Arguments:

    pDevice - a pointer to the PBC device context
    pRequest - a pointer to the PBC request context

  Return Value:

    STATUS_SUCCESS on success (including a data NAK, which is reported as
    a short transfer via pRequest->Information). An error status if the
    controller timed out or reported a protocol error.

--*/
{
    FuncEntry(TRACE_FLAG_TRANSFER);

    NTSTATUS status = STATUS_SUCCESS;
    ULONG hwStatus = 0;
    PPBC_TARGET pTarget = pDevice->pCurrentTarget;
    UCHAR address7Bit = (UCHAR)(pTarget->Settings.Address & 0x7F);

    if (pRequest->Direction == SpbTransferDirectionToDevice)
    {
        //
        // Write: transmit each byte and watch for a data NAK.
        //

        for (size_t i = 0; i < pRequest->Length; i++)
        {
            UCHAR dataByte;

            status = PbcRequestGetByte(pRequest, i, &dataByte);

            if (!NT_SUCCESS(status))
            {
                goto exit;
            }

            status = QemuI2cIssueCommand(
                pDevice,
                QEMU_I2C_CMD_TX,
                dataByte,
                &hwStatus);

            if (!NT_SUCCESS(status))
            {
                goto exit;
            }

            if (TestAnyBits(hwStatus, QEMU_I2C_STATUS_PROTO_ERR))
            {
                status = STATUS_IO_DEVICE_ERROR;
                goto exit;
            }

            if (TestAnyBits(hwStatus, QEMU_I2C_STATUS_NAK))
            {
                //
                // Data NAK: the target accepted fewer bytes than offered.
                // This is reported to the client as a short (successful)
                // transfer.
                //

                Trace(
                    TRACE_LEVEL_WARNING,
                    TRACE_FLAG_TRANSFER,
                    "Data NACK after %Iu byte(s) for address 0x%lx",
                    pRequest->Information,
                    pTarget->Settings.Address);

                status = STATUS_SUCCESS;
                goto exit;
            }

            pRequest->Information = i + 1;
        }
    }
    else
    {
        //
        // Read: request bursts of up to 256 bytes and drain the RX FIFO.
        //

        size_t offset = 0;
        size_t remaining = pRequest->Length;
        BOOLEAN firstChunk = TRUE;

        while (remaining > 0)
        {
            ULONG chunk;

            //
            // After the first burst the controller requires a (repeated)
            // START before another RX burst.
            //

            if (!firstChunk)
            {
                status = QemuI2cStart(pDevice, address7Bit, TRUE, &hwStatus);

                if (!NT_SUCCESS(status))
                {
                    goto exit;
                }

                if (TestAnyBits(hwStatus, QEMU_I2C_STATUS_PROTO_ERR))
                {
                    status = STATUS_IO_DEVICE_ERROR;
                    goto exit;
                }

                if (TestAnyBits(hwStatus, QEMU_I2C_STATUS_NAK))
                {
                    status = STATUS_NO_SUCH_DEVICE;
                    goto exit;
                }
            }

            chunk = (remaining > QEMU_I2C_RX_FIFO_SIZE) ?
                QEMU_I2C_RX_FIFO_SIZE : (ULONG)remaining;

            //
            // Kick off the burst. The DATA field is (count - 1).
            //

            status = QemuI2cIssueCommand(
                pDevice,
                QEMU_I2C_CMD_RX,
                (UCHAR)(chunk - 1),
                &hwStatus);

            if (!NT_SUCCESS(status))
            {
                goto exit;
            }

            if (TestAnyBits(hwStatus, QEMU_I2C_STATUS_PROTO_ERR))
            {
                status = STATUS_IO_DEVICE_ERROR;
                goto exit;
            }

            if (TestAnyBits(hwStatus, QEMU_I2C_STATUS_NAK))
            {
                status = STATUS_NO_SUCH_DEVICE;
                goto exit;
            }

            //
            // Drain the requested bytes from the RX FIFO.
            //

            for (ULONG j = 0; j < chunk; j++)
            {
                ULONG drainStatus;
                ULONG value;

                status = QemuI2cPollStatus(
                    pDevice,
                    QEMU_I2C_STATUS_RX_RDY,
                    &drainStatus);

                if (!NT_SUCCESS(status))
                {
                    goto exit;
                }

                value = pDevice->pRegisters->Data.Read();

                status = PbcRequestSetByte(
                    pRequest,
                    offset,
                    (UCHAR)(value & QEMU_I2C_DATA_DATA_MASK));

                if (!NT_SUCCESS(status))
                {
                    goto exit;
                }

                offset++;
                pRequest->Information = offset;
            }

            remaining -= chunk;
            firstChunk = FALSE;
        }
    }

exit:

    FuncExit(TRACE_FLAG_TRANSFER);

    return status;
}

VOID
ControllerCompleteTransfer(
    _In_  PPBC_DEVICE   pDevice,
    _In_  PPBC_REQUEST  pRequest,
    _In_  BOOLEAN       AbortSequence
    )
/*++
 
  Routine Description:

    This routine completes a data transfer. Unless there are
    more transfers remaining in the sequence, the request is
    marked complete.

  Arguments:

    pDevice - a pointer to the PBC device context
    pRequest - a pointer to the PBC request context
    AbortSequence - specifies whether the driver should abort the
        ongoing sequence or begin the next transfer

  Return Value:

    None.

--*/
{
    FuncEntry(TRACE_FLAG_TRANSFER);

    NT_ASSERT(pDevice  != NULL);
    NT_ASSERT(pRequest != NULL);

    Trace(
        TRACE_LEVEL_INFORMATION,
        TRACE_FLAG_TRANSFER,
        "Transfer (index %lu) %s with %Iu bytes for address 0x%lx "
        "(SPBREQUEST %p)",
        pRequest->TransferIndex,
        NT_SUCCESS(pRequest->Status) ? "complete" : "error",
        pRequest->Information,
        pDevice->pCurrentTarget->Settings.Address,
        pRequest->SpbRequest);

    //
    // Update request context with information from this transfer.
    //

    pRequest->TotalInformation += pRequest->Information;
    pRequest->Information = 0;

    //
    // Check if there are more transfers
    // in the sequence.
    //

    if (!AbortSequence)
    {
        pRequest->TransferIndex++;

        if (pRequest->TransferIndex < pRequest->TransferCount)
        {
            //
            // Configure the request for the next transfer.
            //

            pRequest->Status = PbcRequestConfigureForIndex(
                pRequest, 
                pRequest->TransferIndex);

            if (NT_SUCCESS(pRequest->Status))
            {
                //
                // Configure controller and start the next transfer.
                //

                PbcRequestDoTransfer(pDevice, pRequest);
                goto exit;
            }
        }
    }

    //
    // Done or error occurred. Set interrupt mask to 0.
    //

    PbcDeviceSetInterruptMask(pDevice, 0);

    //
    // Clear the target's current request. This will prevent
    // the request context from being accessed once the request
    // is completed (and the context is invalid).
    //

    pDevice->pCurrentTarget->pCurrentRequest = NULL;

    //
    // Clear the controller's current target if any of
    //   1. request is type sequence
    //   2. request position is single 
    //      (did not come between lock/unlock)
    // Otherwise wait until unlock.
    //

    if ((pRequest->Type == SpbRequestTypeSequence) ||
        (pRequest->SequencePosition == SpbRequestSequencePositionSingle))
    {
        pDevice->pCurrentTarget = NULL;
    }

    //
    // Mark the IO complete. The request is completed by the caller
    // (the SPB IO callback) once this synchronous transfer returns.
    //

    pRequest->bIoComplete = TRUE;

exit:

    FuncExit(TRACE_FLAG_TRANSFER);
}

/////////////////////////////////////////////////
//
// Interrupt helpers.
//
// The QEMU controller exposes no interrupt resource, so the driver runs
// in polled mode and these routines are not used at run time. They are
// retained as functional register accessors so the (unwired) ISR/DPC
// scaffolding continues to compile and so the driver can be converted to
// interrupt-driven operation if a future platform wires up the IRQ.
//
/////////////////////////////////////////////////

VOID
ControllerEnableInterrupts(
    _In_  PPBC_DEVICE   pDevice,
    _In_  ULONG         InterruptMask
    )
{
    FuncEntry(TRACE_FLAG_TRANSFER);

    NT_ASSERT(pDevice != NULL);

    if (pDevice->pRegisters != NULL)
    {
        pDevice->pRegisters->Ctrl.SetBits(InterruptMask & QEMU_I2C_CTRL_IE_MASK);
    }

    FuncExit(TRACE_FLAG_TRANSFER);
}

VOID
ControllerDisableInterrupts(
    _In_  PPBC_DEVICE   pDevice
    )
{
    FuncEntry(TRACE_FLAG_TRANSFER);

    NT_ASSERT(pDevice != NULL);

    if (pDevice->pRegisters != NULL)
    {
        pDevice->pRegisters->Ctrl.ClearBits(QEMU_I2C_CTRL_IE_MASK);
    }

    FuncExit(TRACE_FLAG_TRANSFER);
}

ULONG
ControllerGetInterruptStatus(
    _In_  PPBC_DEVICE   pDevice,
    _In_  ULONG         InterruptMask
    )
{
    FuncEntry(TRACE_FLAG_TRANSFER);

    ULONG interruptStatus = 0;

    NT_ASSERT(pDevice != NULL);

    if (pDevice->pRegisters != NULL)
    {
        interruptStatus = pDevice->pRegisters->Status.Read() & InterruptMask;
    }

    FuncExit(TRACE_FLAG_TRANSFER);

    return interruptStatus;
}

VOID
ControllerAcknowledgeInterrupts(
    _In_  PPBC_DEVICE   pDevice,
    _In_  ULONG         InterruptMask
    )
{
    FuncEntry(TRACE_FLAG_TRANSFER);

    NT_ASSERT(pDevice != NULL);

    if (pDevice->pRegisters != NULL)
    {
        pDevice->pRegisters->Status.Write(InterruptMask & QEMU_I2C_STATUS_W1C_MASK);
    }

    FuncExit(TRACE_FLAG_TRANSFER);
}

VOID
ControllerProcessInterrupts(
    _In_  PPBC_DEVICE   pDevice,
    _In_  PPBC_REQUEST  pRequest,
    _In_  ULONG         InterruptStatus
    )
/*++

  Routine Description:

    Not used in polled mode. Retained for ISR/DPC scaffolding.

--*/
{
    FuncEntry(TRACE_FLAG_TRANSFER);

    UNREFERENCED_PARAMETER(pDevice);
    UNREFERENCED_PARAMETER(pRequest);
    UNREFERENCED_PARAMETER(InterruptStatus);

    FuncExit(TRACE_FLAG_TRANSFER);
}
