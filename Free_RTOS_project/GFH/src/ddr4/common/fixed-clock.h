/* Copyright 2018 SiFive, Inc */
/* SPDX-License-Identifier: Apache-2.0 */

#ifndef METAL__DRIVERS__FIXED_CLOCK_H
#define METAL__DRIVERS__FIXED_CLOCK_H

struct __metal_driver_fixed_clock;

#include </home/admin1/FLC/zybo_E21/metal/inc/clock.h>
#include </home/admin1/FLC/zybo_E21/metal/inc/compiler.h>

struct __metal_driver_vtable_fixed_clock {
    struct __metal_clock_vtable clock;
};

__METAL_DECLARE_VTABLE(__metal_driver_vtable_fixed_clock)

struct __metal_driver_fixed_clock {
    struct metal_clock clock;
};

#endif
