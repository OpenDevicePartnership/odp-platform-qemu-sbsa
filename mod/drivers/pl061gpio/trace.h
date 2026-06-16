/*++

Copyright (c) Microsoft Corporation.  All rights reserved.

Module Name:

    trace.h

Abstract:

    WPP tracing definitions for pl061gpio.

Environment:

    Kernel mode

--*/

#ifndef _PL061GPIO_TRACE_H_
#define _PL061GPIO_TRACE_H_

#include <evntrace.h>

// Tracing GUID: 53b99646-12f7-4d29-95cb-159f73f5f38b
#define WPP_CONTROL_GUIDS                                              \
    WPP_DEFINE_CONTROL_GUID(                                           \
        Pl061GpioTraceGuid,                                            \
        (53b99646,12f7,4d29,95cb,159f73f5f38b),                        \
        WPP_DEFINE_BIT(TRACE_FLAG_INIT)                                \
        WPP_DEFINE_BIT(TRACE_FLAG_PNP)                                 \
        WPP_DEFINE_BIT(TRACE_FLAG_GPIO)                                \
        WPP_DEFINE_BIT(TRACE_FLAG_INTERRUPT)                           \
        WPP_DEFINE_BIT(TRACE_FLAG_IO)                                  \
    )

#define WPP_FLAG_LEVEL_LOGGER(flag, level) \
    WPP_LEVEL_LOGGER(flag)

#define WPP_FLAG_LEVEL_ENABLED(flag, level) \
    (WPP_LEVEL_ENABLED(flag) && WPP_CONTROL(WPP_BIT_ ## flag).Level >= level)

#define WPP_LEVEL_FLAGS_LOGGER(lvl, flags) \
    WPP_LEVEL_LOGGER(flags)

#define WPP_LEVEL_FLAGS_ENABLED(lvl, flags) \
    (WPP_LEVEL_ENABLED(flags) && WPP_CONTROL(WPP_BIT_ ## flags).Level >= lvl)

// begin_wpp config
// FUNC TraceEvents(LEVEL, FLAGS, MSG, ...);
// FUNC FuncEntry{LEVEL=TRACE_LEVEL_VERBOSE}(FLAGS);
// FUNC FuncExit{LEVEL=TRACE_LEVEL_VERBOSE}(FLAGS);
// USEPREFIX(FuncEntry, "%!STDPREFIX! [%!FUNC!] --> entry");
// USEPREFIX(FuncExit, "%!STDPREFIX! [%!FUNC!] <-- exit");
// end_wpp

#endif // _PL061GPIO_TRACE_H_
