//
// Test controller device node for the QEMU "ODP socket-backed I2C
// controller".
//
// This mirrors the controller node published by the QEMU SBSA / arm-virt
// platform firmware (philgweber/odp-platform-qemu-sbsa hid.asl). The
// controller exposes a single 0x1000-byte MMIO register window and no
// interrupt line, so this driver services transfers by polling.
//
// For a peripheral driver to access this controller via SPB it must
// specify the ACPI device path within the I2CSerialBus macro, e.g.
// "\_SB.I2C0".
//
Device(I2C0)
{
    Name(_HID, "QEMU0001")
    Name(_UID, 1)

    Name(_CRS, ResourceTemplate()
    {
        Memory32Fixed(ReadWrite, 0x090d0000, 0x00001000)
    })
}