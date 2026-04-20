/** @file
  Contains root level name space objects for the platform

  Copyright (c) 2024 - 2025, MediaTek Inc. All rights reserved.<BR>
  SPDX-License-Identifier: BSD-2-Clause-Patent

**/

Device (PSU0)
{
  Name (_HID, "ACPI0003")  // _UID: Unique ID
  Name (_UID, 0)  // _UID: Unique ID
  Name (_PCL, Package () { \_SB })  // _PCL: Power Consumer List

  // BatteryCommand::GetPsr => 0x3,
  // BatteryCommand::GetPif => 0x4,
  Name( PIFD, Package(6) {
    0,          // Out - Power Source State
    0,          // Out - Maximum Output Power
    0,          // Out - Maximum Input Power
    "        ", // Out - Model Number
    "        ", // Out - Serial Number
    "        "  // Out - OEM Information
  })

  Name(BUFF, Buffer(144){})   // Create buffer for send/recv data
  
  // Disable Battery by default
  Method (_STA, 0, NotSerialized) {
    Return (0x0)
  }


  Method (_PSR, 0, Serialized) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateDwordField(BUFF,32,PSR0)  // Out – Power Source 

      Store(0x3, CMDD) //EC_BAT_GET_PSR
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      If(LEqual(STAT,0x0) ) // Check FF-A successful?
      {
        return(PSR0)
      }

    Return(0)
  }

  Method (_PIF, 0, Serialized) {
    CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32,CMDD) //  In – First byte of command
    CreateDwordField(BUFF,32,PIF0)  // Out – Power Source State
    CreateDwordField(BUFF,36,PIF1)  // Out – Maximum Output Power
    CreateDwordField(BUFF,40,PIF2)  // Out – Maximum Input Power
    CreateField(BUFF,352,64,PIF3)  // Out – Model Number
    CreateField(BUFF,416,64,PIF4)  // Out – Serial Number 
    CreateField(BUFF,480,64,PIF5)  // Out – OEM Information

    Store(0x4, CMDD) //EC_BAT_GET_PIF
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
    PIFD[0] = PIF0
    PIFD[1] = PIF1
    PIFD[2] = PIF2
    PIFD[3] = PIF3
    PIFD[4] = PIF4
    PIFD[5] = PIF5

    }
    Return(PIFD)
  }




}

Device (BAT0)
{
  Name (_HID, EisaId ("PNP0C0A") /* Control Method Battery */)  // _HID: Hardware ID
  Name (_UID, 0)  // _UID: Unique ID

  Name(BUFF, Buffer(144){})   // Create buffer for send/recv data
  
  // Disable Battery by default
  Method (_STA, 0, NotSerialized) {
    Return (0x0)
  }

  // BatteryCommand::GetBix => 0x1,
  // BatteryCommand::GetBst => 0x2,
  // BatteryCommand::GetBps => 0x5,
  // BatteryCommand::SetBtp => 0x6,
  // BatteryCommand::SetBpt => 0x7,
  // BatteryCommand::GetBpc => 0x8,
  // BatteryCommand::SetBmc => 0x9,
  // BatteryCommand::GetBmd => 0xa,
  // BatteryCommand::GetBct => 0xb,
  // BatteryCommand::GetBtm => 0xc,
  // BatteryCommand::SetBms => 0xd,
  // BatteryCommand::SetBma => 0xe,
  // BatteryCommand::GetSta => 0xf,
  
  // Initialize all the default return values
  // Note embedded package doesn't work need to assign and modify
  Name (BSTD, Package (4) {
    0x2,
    0x500,
    0x10000,
    0x3C28
  })

  Name (BIXD, Package(21) {
    0,
    0,
    0x15F90,
    0x15F90,
    1,
    0x3C28,
    0x8F,
    0xE10,
    1,
    0x17318,
    0x03E8,
    0x03E8,
    0x03E8,
    0x03E8,
    0x380,
    0xE1,
    "12345678",
    "22222222",
    "33333333",
    "44444444",
    0x0
  })

  Name( BPSD, Package(5) {
    0,  // Out – Revision
    0,  // Out – Instantaneous Peak Power Level
    0,  // Out – Instantaneous Peak Power Period
    0,  // Out – Sustainable Peak Power Level
    0  // Out – Sustainable Peak Power Period
  })

  Name( BPCD, Package(4) {
    0,  // Out - Revision
    0,  // Out - Threshold support
    0,  // Out - Max Inst peak power
    0  // Out - Max Sust peak power
  })

  Name( BMDD, Package(5) {
    0,  // Out - Status
    0,  // Out - Capability Flags
    0,  // Out - Recalibrate count
    0,  // Out - Quick recal time
    0 // Out - Slow recal time
  })

  Method (_BIX, 0, Serialized) {
    CreateDwordField(BUFF,0,STAT)   // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID)  // UUID of service
    CreateByteField(BUFF,32,CMDD)   //  In – First byte of command
    CreateByteField(BUFF,33,BTID)   //  In - Battery ID
    CreateDwordField(BUFF,32,BIX0)  // Out – Revision
    CreateDwordField(BUFF,36,BIX1)  // Out – Power Unit
    CreateDwordField(BUFF,40,BIX2)  // Out – Design Capacity
    CreateDwordField(BUFF,44,BIX3)  // Out – Last Full Charge Capacity
    CreateDwordField(BUFF,48,BIX4)  // Out – Battery Technology
    CreateDwordField(BUFF,52,BIX5)  // Out – Design Voltage
    CreateDwordField(BUFF,56,BIX6)  // Out – Design Capacity of Warning
    CreateDwordField(BUFF,60,BIX7)  // Out – Design Capacity of Low
    CreateDwordField(BUFF,64,BIX8)  // Out – Cycle Count
    CreateDwordField(BUFF,68,BIX9)  // Out – Measurement Accuracy
    CreateDwordField(BUFF,72,BI10)  // Out – Max Sampling Time
    CreateDwordField(BUFF,76,BI11)  // Out – Min Sampling Time
    CreateDwordField(BUFF,80,BI12)  // Out – Max Averaging Internal
    CreateDwordField(BUFF,84,BI13)  // Out – Min Averaging Interval
    CreateDwordField(BUFF,88,BI14)  // Out – Battery Capacity Granularity 1
    CreateDwordField(BUFF,92,BI15)  // Out – Battery Capacity Granularity 2
    CreateField(BUFF,768,64,BI16)   // Out – Model Number
    CreateField(BUFF,832,64,BI17)   // Out – Serial number
    CreateField(BUFF,896,64,BI18)   // Out – Battery Type
    CreateField(BUFF,960,64,BI19)   // Out – OEM Information
    CreateDwordField(BUFF,128,BI20) // Out – OEM Information

    Store(0x1, CMDD) //EC_BAT_GET_BIX
    Store(0x0, BTID) // Battery 0
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
        BIXD[0] = BIX0
        BIXD[1] = BIX1
        BIXD[2] = BIX2
        BIXD[3] = BIX3
        BIXD[4] = BIX4
        BIXD[5] = BIX5
        BIXD[6] = BIX6
        BIXD[7] = BIX7
        BIXD[8] = BIX8
        BIXD[9] = BIX9
        BIXD[10] = BI10
        BIXD[11] = BI11
        BIXD[12] = BI12
        BIXD[13] = BI13
        BIXD[14] = BI14
        BIXD[15] = BI15
        BIXD[16] = BI16
        BIXD[17] = BI17
        BIXD[18] = BI18
        BIXD[19] = BI19
        BIXD[20] = BI20
    }
    Return(BIXD)
  }

  Method (_BST, 0, Serialized) {
    CreateDwordField(BUFF,0,STAT)   // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID)  // UUID of service
    CreateByteField(BUFF,32,CMDD)   //  In – First byte of command
    CreateByteField(BUFF,33,BTID)   //  In - Battery ID
    CreateDwordField(BUFF,32,BST0)  // Out – Battery State DWord
    CreateDwordField(BUFF,36,BST1)  // Out – Battery Rate DWord
    CreateDwordField(BUFF,40,BST2)  // Out – Battery Reamining Capacity DWord
    CreateDwordField(BUFF,44,BST3)  // Out – Battery Voltage DWord

    Store(0x2, CMDD) //EC_BAT_GET_BST
    Store(0x0, BTID) // Battery 0
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)

    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
        BSTD[0] = BST0
        BSTD[1] = BST1
        BSTD[2] = BST2
        BSTD[3] = BST3
    }
    Return(BSTD)
  }

  Method (_BPS, 0, Serialized) {
    CreateDwordField(BUFF,0,STAT)   // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID)  // UUID of service
    CreateByteField(BUFF,32,CMDD)   //  In – First byte of command
    CreateByteField(BUFF,33,BTID)   //  In - Battery ID
    CreateDwordField(BUFF,32,BPS0)  // Out – Revision
    CreateDwordField(BUFF,36,BPS1)  // Out – Instantaneous Peak Power Level
    CreateDwordField(BUFF,40,BPS2)  // Out – Instantaneous Peak Power Period
    CreateDwordField(BUFF,44,BPS3)  // Out – Sustainable Peak Power Level
    CreateDwordField(BUFF,48,BPS4)  // Out – Sustainable Peak Power Period

    Store(0x5, CMDD) //EC_BAT_GET_BPS
    Store(0x0, BTID) // Battery 0
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
        BPSD[0] = BPS0
        BPSD[1] = BPS1
        BPSD[2] = BPS2
        BPSD[3] = BPS3
        BPSD[4] = BPS4
    }
    Return(BPSD)
  }

  Method (_BTP, 1, Serialized) {
    CreateDwordField(BUFF,0,STAT)  // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32,CMDD)  //  In – First byte of command
    CreateByteField(BUFF,33,BTID)  //  In - Battery ID
    CreateDwordField(BUFF,36,BTP0) //  In - Trip point value

    Store(0x0, BTID) // Battery 0
    Store(0x6, CMDD) //EC_BAT_SET_BTP
    Store(Arg0, BTP0) 
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    Return(Zero)
  }

  Method (_BPT, 3, Serialized) {
    CreateDwordField(BUFF,0,STAT)   // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID)  // UUID of service
    CreateByteField(BUFF,32,CMDD)   //  In – First byte of command
    CreateByteField(BUFF,33,BTID)   //  In - Battery ID
    CreateDwordField(BUFF,36,BPT0)  //  In - Revision
    CreateDwordField(BUFF,40,BPT1)  //  In - Threshold ID
    CreateDwordField(BUFF,44,BPT2)  //  In - Threshold value
    CreateDwordField(BUFF,32,BPTS)  // Out - Trip point value

    Store(0x7, CMDD) //EC_BAT_SET_BPT
    Store(0x0, BTID) // Battery 0
    Store(Arg0, BPT0) 
    Store(Arg1, BPT1) 
    Store(Arg2, BPT2) 
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
        return(BPTS)
    }
    Return(Zero)
  }

  Method (_BPC, 0, Serialized) {
    CreateDwordField(BUFF,0,STAT)  // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32,CMDD)  //  In – First byte of command
    CreateByteField(BUFF,33,BTID)  //  In - Battery ID
    CreateDwordField(BUFF,32,BPC0) // Out - Revision
    CreateDwordField(BUFF,36,BPC1) // Out - Threshold support
    CreateDwordField(BUFF,40,BPC2) // Out - Max Inst peak power
    CreateDwordField(BUFF,44,BPC3) // Out - Max Sust peak power

    
    Store(0x8, CMDD) //EC_BAT_GET_BPC
    Store(0x0, BTID) // Battery 0
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
        BPCD[0] = BPC0
        BPCD[1] = BPC1
        BPCD[2] = BPC2
        BPCD[3] = BPC3
    }
    Return(BPCD)
  }

  Method (_BMC, 1, Serialized) {
    CreateDwordField(BUFF,0,STAT)  // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32,CMDD)  //  In – First byte of command
    CreateByteField(BUFF,33,BTID)  //  In - Battery ID
    CreateDwordField(BUFF,36,BMC0) //  In - Feature control flags

    Store(0x9, CMDD) //EC_BAT_SET_BMC
    Store(0x0, BTID) // Battery 0
    Store(Arg0, BMC0) 
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    Return(Zero)
  }

  Method (_BMD, 0, Serialized) {
    CreateDwordField(BUFF,0,STAT)  // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32,CMDD)  //  In – First byte of command
    CreateByteField(BUFF,33,BTID)  //  In - Battery ID
    CreateDwordField(BUFF,32,BMD0) // Out - Status
    CreateDwordField(BUFF,36,BMD1) // Out - Capability Flags
    CreateDwordField(BUFF,40,BMD2) // Out - Recalibrate count
    CreateDwordField(BUFF,44,BMD3) // Out - Quick recal time
    CreateDwordField(BUFF,48,BMD4) // Out - Slow recal time

    Store(0xa, CMDD) //EC_BAT_GET_BMD
    Store(0x0, BTID) // Battery 0
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
        BMDD[0] = BMD0
        BMDD[1] = BMD1
        BMDD[2] = BMD2
        BMDD[3] = BMD3
        BMDD[4] = BMD4
    }
    Return(BMDD)
  }

  Method (_BCT, 1, Serialized) {
    CreateDwordField(BUFF,0,STAT)  // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32,CMDD)  //  In – First byte of command
    CreateByteField(BUFF,33,BTID)  //  In - Battery ID
    CreateDwordField(BUFF,36,BCT0) //  In - ChargeLevel
    CreateDwordField(BUFF,32,BCTD) // Out - Result

    Store(0xb, CMDD) //EC_BAT_GET_BCT
    Store(0x0, BTID) // Battery 0
    Store(Arg0, BCT0)
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
        return(BCTD)
    }
    Return(Zero)
  }

  Method (_BTM, 1, Serialized) {
    CreateDwordField(BUFF,0,STAT)  // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32,CMDD)  //  In – First byte of command
    CreateByteField(BUFF,33,BTID)  //  In - Battery ID
    CreateDwordField(BUFF,36,BTM0) // In - Expected rate
    CreateDwordField(BUFF,32,BTMD) // Out - Discharge rate

    Store(0xc, CMDD) //EC_BAT_GET_BTM
    Store(0x0, BTID) // Battery 0
    Store(Arg0, BTM0) 
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
        return(BTMD)
    }
    Return(Zero)
  }


  Method (_BMS, 1, Serialized) {
    CreateDwordField(BUFF,0,STAT)  // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32,CMDD)  //  In – First byte of command
    CreateByteField(BUFF,33,BTID)  //  In - Battery ID
    CreateDwordField(BUFF,36,BMS0) //  In - Sampling Time
    CreateDwordField(BUFF,32,BMSD) // Out - Result code

    Store(0xd, CMDD) //EC_BAT_SET_BMS
    Store(0x0, BTID) // Battery 0
    Store(Arg0, BMS0) 
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
        return(BMSD)
    }
    Return(Zero)
  }
  
  Method (_BMA, 1, Serialized) {
    CreateDwordField(BUFF,0,STAT)  // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32,CMDD)  //  In – First byte of command
    CreateByteField(BUFF,33,BTID)  //  In - Battery ID
    CreateDwordField(BUFF,36,BMA0) //  In - Averaging Interval
    CreateDwordField(BUFF,32,BMAD) // Out - Result code

    Store(0xe, CMDD) //EC_BAT_SET_BMA
    Store(0x0, BTID) // Battery 0
    Store(Arg0, BMA0) 
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
        return(BMAD)
    }
    Return(Zero)
  }

  Method (BSTA, 0, Serialized) {
    CreateDwordField(BUFF,0,STAT)  // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32,CMDD)  //  In – First byte of command
    CreateByteField(BUFF,33,BTID)  //  In - Battery ID
    CreateDwordField(BUFF,32,STAD) // Out - Battery supported info

    Store(0xf, CMDD) //EC_BAT_GET_STA
    Store(0x0, BTID) // Battery 0
    Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
        return(STAD)
    }
    Return(Zero)
  }

  Method (BNFY, 1, Serialized) {
    Switch (Arg0)
    {
      // Power supply notify event
      Case(0x2)
      {
      }
      Case(0x3)
      {
      }
    }
    Return(Zero)
  }

  Method (TNFY, 0, Serialized) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD) //  In – First byte of command
      CreateByteField(BUFF,33,BTID)   //  In - Battery ID

      Store(0x80, CMDD) //EC_BAT_TEST_NFY
      Store(0x0, BTID) // Battery 0
      Store(ToUUID("25cb5207-ac36-427d-aaef-3aa78877d27e"), UUID)

      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      Return(Zero)
  }

}
