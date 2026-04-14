/** @file
  Contains root level name space objects for the platform

  Copyright (c) 2024, MediaTek Inc. All rights reserved.<BR>
  SPDX-License-Identifier: BSD-2-Clause-Patent

**/


#include "battery.asl"
#include "thermal.asl"
#include "rtc.asl"


//
// EC Test interface to load KMDF driver and map methods
//
Device (ECT0) {
  Name (_HID, "ETST0001")
  Name (_UID, 0x0)
  Name (_CCA, 0x0)

  /*********************** General Methods **********************************/
  Name (NEVT, 0x1234)

  Name(BUFF, Buffer(144){})   // Create buffer for send/recv data
 
  Method(ECHO, 0x1, NotSerialized) {
    Return(Arg0) // Echo back input
  }

  Method (_STA) {
    Return (0xf)
  }

  // Call interrupt handler for VWire events
  Method(INTH, 0x0, NotSerialized) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,72,CMDD)  // In – First byte of command
    
      Store(6, CMDD) // NFY Interrupt
      Store(ToUUID("e474d87e-5731-4044-a727-cb3e8cf3c8df"), UUID)
      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
  }
  
  /******************* Debug Service Methods *********************************/
  Method(DMSG, 0x0, NotSerialized) {
      CreateDwordField(BUFF,0,STAT) // Out – Status for req/rsp
      CreateField(BUFF,128,128,UUID) // UUID of service
      CreateByteField(BUFF,32,CMDD)  // In – First byte of command
      CreateField(BUFF,256,896,MSGD) // Copy all output buffer

      Store(1, CMDD) // GET_MSG
      Store(ToUUID("0bd66c7c-a288-48a6-afc8-e2200c03eb62"), UUID)
      Store(Store(BUFF, \_SB_.FFA0.FFAC), BUFF)
      Return(MSGD)
  }

  
  /******************* Battery Test Methods **********************************/
  Method(TBIX, 0x0, NotSerialized) {
    Return (\_SB.BAT0._BIX())
  }

  Method(TBST, 0x0, NotSerialized) {
    Return (\_SB.BAT0._BST())
  }

  Method(TPSR, 0x0, NotSerialized) {
    Return (\_SB.PSU0._PSR())
  }

  Method(TPIF, 0x0, NotSerialized) {
    Return (\_SB.PSU0._PIF())
  }

  Method(TBPS, 0x0, NotSerialized) {
    Return (\_SB.BAT0._BPS())
  }

  Method(TBTP, 0x0, NotSerialized) {
    Return (\_SB.BAT0._BTP(1000))
  }
  
  Method(TBPT, 0x0, NotSerialized) {
    Return(\_SB.BAT0._BPT(1,20,100))
  }

  Method(TBPC, 0x0, NotSerialized) {
    Return(\_SB.BAT0._BPC())
  }

  Method(TBMC, 0x0, NotSerialized) {
    Return(\_SB.BAT0._BMC(0x1))
  }

  Method(TBMD, 0x0, NotSerialized) {
    Return(\_SB.BAT0._BMD())
  }

  Method(TBCT, 0x0, NotSerialized) {
    Return(\_SB.BAT0._BCT(5000))
  }

  Method(TBTM, 0x0, NotSerialized) {
    Return(\_SB.BAT0._BTM(500))
  }

  Method(TBMS, 0x0, NotSerialized) {
    Return(\_SB.BAT0._BMS(1000))
  }

  Method(TBMA, 0x0, NotSerialized) {
    Return(\_SB.BAT0._BMA(5000))
  }

  Method(BNFY, 0x0, NotSerialized) {
    Return(\_SB.BAT0.TNFY())
  }

  /******************* Thermal Test Methods **********************************/
  Method(RFAN, 0x0, NotSerialized) {
    // Read input function 3
    Return(\_SB.CIO1._DSM(ToUuid("07ff6382-e29a-47c9-ac87-e79dad71dd82"),1,3,0))
  }

  Method(WFAN, 0x0, NotSerialized) {
    // Write output function 3 to 1500 RPM
    Return(\_SB.CIO1._DSM(ToUuid("d9b9b7f3-2a3e-4064-8841-cb13d317669e"),1,3,1500))
  }

  Method(RTMP, 0x0, NotSerialized) {
    Return(\_SB.SKIN._TMP())
  }

  Method(TDSM, 0x4, NotSerialized) {
    // Arg0 GUID
    //      07ff6382-e29a-47c9-ac87-e79dad71dd82 - Input
    //      d9b9b7f3-2a3e-4064-8841-cb13d317669e - Output
    // Arg1 Revision
    // Arg2 Function Index
    // Arg3 Function dependent
    Return(\_SB.CIO1._DSM(Arg0,Arg1,Arg2,Arg3))
  }

  Method(TSVR, 0x3, NotSerialized) {
    // Thermal Set Var
    // Arg0 - Instance ID
    // Arg1 - Variable UUID
    // Arg2 - Value
    Return(\_SB.CIO1.SVAR(Arg0,Arg1,Arg2))
  }
  
  Method(TGVR, 0x2, NotSerialized) {
    // Thermal Get Var
    // Arg0 - Instance ID
    // Arg1 - Variable UUID
    Return(\_SB.CIO1.GVAR(Arg0,Arg1))
  }

  /******************* Time/Alarm Test Methods **********************************/

  // Get capabilities
  Method (_GCP, 0, Serialized) {
    Return(\_SB.RTC._GCP())
  }

  // Get Real Time
  Method (_GRT, 0, Serialized) {
    Return(\_SB.RTC._GRT())
  }

  // Set Real Time
  // Arg0 - Buffer containing the timestamp to set the clock to
  Method (_SRT, 1, Serialized) {
    Return(\_SB.RTC._SRT(Arg0))
  }

  // Get Wake Settings
  // Arg0 - Timer ID (AC or DC)
  Method (_GWS, 1, Serialized) {
    Return(\_SB.RTC._GWS(Arg0))
  }

  // Clear Wake Status
  // Arg0 - Timer ID (AC or DC)
  Method (_CWS, 1, Serialized) {
    Return(\_SB.RTC._CWS(Arg0))
  }

  // Set Timer Value
  // Arg0 - Timer ID (AC or DC)
  // Arg1 - Timer Value
  Method (_STV, 2, NotSerialized) {
    Return(\_SB.RTC._STV(Arg0, Arg1))
  }

  // Get Timer Value
  // Arg0 - Timer ID (AC or DC)
  Method (_TIV, 1, Serialized) {
    Return(\_SB.RTC._TIV(Arg0))
  }

  // Set expired timer wake policy
  // Arg0 - Timer ID (AC or DC)
  // Arg1 - Expired timer wake policy
  Method (_STP, 2, NotSerialized) {
    Return(\_SB.RTC._STP(Arg0, Arg1))
  }

  // Get expired timer wake policy
  // Arg0 - Timer ID (AC or DC)
  Method (_TIP, 1, Serialized) {
    Return(\_SB.RTC._TIP(Arg0))
  }

} // Device (ECT0)
