/** @file
  Contains root level name space objects for the platform

  Copyright (c) 2024, MediaTek Inc. All rights reserved.<BR>
  SPDX-License-Identifier: BSD-2-Clause-Patent

**/


Device(RTC) {
    Name (_HID, "ACPI000E")  // _HID: Hardware ID
    Name (_UID, 0)  // _UID: Unique ID
    
    Name(BUFF, Buffer(144){})   // Create buffer for send/recv data

    Name (DGRT, Package (0xB)
    {
      //_GRT output default value
      2025,   // Year
      1,      // Month
      1,      // DAY
      1,      // Hour
      1,      // Minute
      1,      // Second
      0,      // Valid
      0,      // millisecond
      0x07FF, // TimeZone
      0,      // Daylight
      0       // Reserved
    })

    Method (_SRT,1,Serialized) {
        CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
        CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
        CreateField(BUFF,16,128,UUID) // UUID of service
        CreateByteField(BUFF,18, CMDD) // In – First byte of command
        CreateField(BUFF,152,128,SRTD) // In – 128-bit output structure above
        Store(15, LENG)
        Store(0x3, CMDD) // EC_TAS_SET_SRT
        Store(ToUUID("23ea63ed-b593-46ea-b027-8924df88e92f"), UUID) // RTC
        Store(Arg0, SRTD) // SRTD if passed as Input argument
        Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
        If(LEqual(STAT,0x0) ) // Check FF-A successful?
        {
            Return (One) //SUCCESS
        }
        Return(Zero)
    }

    Method (_GRT,0,Serialized) {
        CreateByteField(BUFF,0,STAT) // Out – Status for req/rsp
        CreateByteField(BUFF,1,LENG) // In/Out – Bytes in req, updates bytes returned
        CreateField(BUFF,16,128,UUID) // UUID of service
        CreateByteField(BUFF,18, CMDD) // In – First byte of command
        //Output date time components
        CreateWordField(BUFF, 18, YEAR) //1900 - 9999
        CreateByteField(BUFF, 20, MNTH) //1 - 12
        CreateByteField(BUFF, 21, DAYS) //1-31
        CreateByteField(BUFF, 22, HOUR) // 0-23
        CreateByteField(BUFF, 23, MINS) //0-59
        CreateByteField(BUFF, 24, SECD) //0-59
        Store(20, LENG)
        Store(0x2, CMDD) // EC_TAS_GET_GRT
        Store(ToUUID("23ea63ed-b593-46ea-b027-8924df88e92f"), UUID) // RTC
        // Send the FFA command for espi service sending EMI command to EC
        Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
        Store(20, LENG)
        Store(0x2, CMDD) // EC_TAS_GET_GRT
        Store(ToUUID("23ea63ed-b593-46ea-b027-8924df88e92f"), UUID) // RTC
        // Send FFA command to take the RTC data received from EC
        Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
        DGRT[0] = YEAR
        DGRT[1] = MNTH
        DGRT[2] = DAYS
        DGRT[3] = HOUR
        DGRT[4] = MINS
        DGRT[5] = SECD
        Return (DGRT)
   }
}
