// Sample Definition of FAN ACPI

Device(SKIN) {
  Name(_HID, "MSFT000A")
  
  Name(TVAL,0xDEAD0001)
  Name(DVAL,0xDEAD0001)

  // Disable by default until we are ready
  Method(_STA, 0, Serialized)
  {
    Return (0)
  }

  Name(BUFF, Buffer(144){})   // Create buffer for send/recv data

  Method(_TMP, 0x0, Serialized) {
    CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32,CMDD)  // In – First byte of command
    CreateByteField(BUFF,33,TZID)  // In - Temp Sensor ID
    
    CreateDwordField(BUFF,32,RTMP) // Out – Temp value

    Store(0x1, CMDD) // EC_THM_GET_TMP
    Store(0x2, TZID) // Temp zone ID for SKIIN
    Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID)
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
        Return (RTMP)
    }
    Return (Ones)
  }

  // Arg0 Temp sensor ID
  // Arg1 Package with Low and High set points
  Method(THRS,0x2, Serialized) {
    CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32,CMDD)  // In – First byte of command
    CreateByteField(BUFF,33,TZID)  // In - Temp Sensor ID
    CreateDwordField(BUFF,34,VTIM) // In - Timeout
    CreateDwordField(BUFF,38,VLO)  // In - Low Threshold
    CreateDwordField(BUFF,42,VHI)  // In - High Threshold
    
    CreateDwordField(BUFF,32,TSTS) // Out – Status
    
    Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID)
    Store(0x2, CMDD) // EC_THM_SET_THRS
    Store(Arg0, TZID)
    Store(DeRefOf(Index(Arg1,0)),VTIM)
    Store(DeRefOf(Index(Arg1,1)),VLO)
    Store(DeRefOf(Index(Arg1,2)),VHI)

    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
        Return (TSTS)
    }
    Return (Ones)

  }

  // Arg0 GUID  1f0849fc-a845-4fcf-865c-4101bf8e8d79
  // Arg1 Revision
  // Arg2 Function Index
  // Arg3 Function dependent
  Method(_DSM, 0x4, Serialized) {
    If(LEqual(ToUuid("1f0849fc-a845-4fcf-865c-4101bf8e8d79"),Arg0)) {
      Switch(Arg2) {
        Case (0) {
          Return(0x3) // Support Function 0 and Function 1
        }
        Case (1) {
          Return( THRS(0x2, Arg3) ) // Call to function to set threshold
        }
      }
    }
    
    // Return Invalid Parameter
    Return(1)
  }

}
// MPTFCore Driver
Device(MPC0) {
  Name(_HID, "MSFT000D")
  Name (_UID, 1)

  // Disable by default until we are ready
  Method(_STA, 0, Serialized)
  {
    Return (0)
  }

}

// MPTF Signal IO Client driver
Device(MPSI) {
  Name(_HID, "MSFT0011")
  Name (_UID, 1)

  // Disable by default until we are ready
  Method(_STA, 0, Serialized)
  {
    Return (0)
  }

}

Device(CIO1) {
  Name(_HID, "MSFT000B")
  Name (_UID, 1)
  
  Name(BUFF, Buffer(144){})   // Create buffer for send/recv data

  Name (CIOD, Package (2) {
    0x0,    // Status
    0x0,    // Value
  })

  // Disable by default until we are ready
  Method(_STA, 0, Serialized)
  {
    Return (0)
  }

  // Arg0 Instance ID
  // Arg1 UUID of variable
  // Return (Status,Value)
  Method(GVAR,2,Serialized) {
    CIOD[0] = 3   // Hardware error by default
    CIOD[1] = 0   // Set value to 0 by default
    CreateDwordField(BUFF,0,STAT)  // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32,CMDD)  //  In – First byte of command
    CreateByteField(BUFF,33,INST)  //  In – Thermal Zone identifier
    CreateWordField(BUFF,34,VLEN)  //  In - Variable length
    CreateField(BUFF,288,128,VUID) //  In - UUID or variable to read
    CreateDWordField(BUFF,32,VAL0) // Out – Return status
    CreateDWordField(BUFF,36,VAL1) // Out – Data Value

    Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID)
    Store(0x5, CMDD) // EC_THM_GET_VAR
    Store(Arg0,INST) // Save instance ID
    Store(4,VLEN) // Variable is always DWORD here
    Store(Arg1, VUID)
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
        CIOD[0] = VAL0 // Status
        CIOD[1] = VAL1 // Data
    }
    Return (CIOD)
  }

  // Arg0 Instance ID
  // Arg1 UUID of variable
  // Return (Status,Value)
  Method(SVAR,3,Serialized) {
    CreateDwordField(BUFF,0,STAT)  // Out – Status for req/rsp
    CreateField(BUFF,128,128,UUID) // UUID of service
    CreateByteField(BUFF,32,CMDD)  //  In – First byte of command
    CreateByteField(BUFF,33,INST)  //  In – Thermal Zone identifier
    CreateWordField(BUFF,34,VLEN)  //  In - Variable length
    CreateField(BUFF,288,128,VUID) //  In - UUID or variable to read
    CreateDwordField(BUFF,52,DVAL) //  In - Data value to write
    CreateDwordField(BUFF,32,RVAL) // Out – Return status

    Store(ToUUID("31f56da7-593c-4d72-a4b3-8fc7171ac073"), UUID)
    Store(0x6, CMDD) // EC_THM_SET_VAR
    Store(Arg0,INST) // Save instance ID
    Store(4,VLEN) // Variable is always DWORD here
    Store(Arg1, VUID)
    Store(Arg2,DVAL)
    Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
    If(LEqual(STAT,0x0) ) // Check FF-A successful?
    {
        Return (RVAL)
    }
    Return (3) // Hardware error
  }


  // Arg0 GUID
  //      07ff6382-e29a-47c9-ac87-e79dad71dd82 - Input
  //      d9b9b7f3-2a3e-4064-8841-cb13d317669e - Output
  // Arg1 Revision
  // Arg2 Function Index
  // Arg3 Function dependent
  Method(_DSM, 0x4, Serialized) {
    // Input Variable
    If(LEqual(ToUuid("07ff6382-e29a-47c9-ac87-e79dad71dd82"),Arg0)) {
        Switch(Arg2) {
          Case(0) {
            // We support function 0-3
            Return (Buffer() {0x0f, 0x00, 0x00, 0x00})
          }
          Case(1) {
            Return(GVAR(1,ToUuid("db261c77-934b-45e2-9742-256c62badb7a"))) // MinRPM
          }
          Case(2) {
            Return(GVAR(1,ToUuid("5cf839df-8be7-42b9-9ac5-3403ca2c8a6a"))) // MaxRPM
          }
          Case(3) {
            Return(GVAR(1,ToUuid("adf95492-0776-4ffc-84f3-b6c8b5269683"))) // CurrentRPM
          }
        }
        // If we don't match any parameters set invalid parameter in status
        CIOD[0] = 1
        CIOD[1] = 0
        Return(CIOD)
    }
    // Output Variable
    If(LEqual(ToUuid("d9b9b7f3-2a3e-4064-8841-cb13d317669e"),Arg0)) {
        Switch(Arg2) {
          Case(0) {
            // We support function 0-3
            Return (Buffer() {0x0f, 0x00, 0x00, 0x00})
          }
          Case(1) {
            Return(SVAR(1,ToUuid("db261c77-934b-45e2-9742-256c62badb7a"),Arg3)) // MinRPM
          }
          Case(2) {
            Return(SVAR(1,ToUuid("5cf839df-8be7-42b9-9ac5-3403ca2c8a6a"),Arg3)) // MaxRPM
          }
          Case(3) {
            Return(SVAR(1,ToUuid("adf95492-0776-4ffc-84f3-b6c8b5269683"),Arg3)) // CurrentRPM
          }
        }
        // Invalid parameter
        Return(1)
    }

    Return (1)
  }

}
