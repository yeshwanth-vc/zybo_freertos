/* Copyright 2018 SiFive, Inc */
/* SPDX-License-Identifier: Apache-2.0 */

#ifndef METAL__DRIVERS__SIFIVE_DUTIMER0_H
#define METAL__DRIVERS__SIFIVE_DUTIMER0_H

#include <metal/compiler.h>
#include <metal/io.h>

#include <metal/clock.h>
#include <metal/interrupt.h>
#include <metal/dutimer.h>

struct __metal_driver_vtable_sifive_dutimer0 {
    const struct metal_dutimer_vtable dutimer;
};

struct __metal_driver_sifive_dutimer0;

__METAL_DECLARE_VTABLE(__metal_driver_vtable_sifive_dutimer0)

struct __metal_driver_sifive_dutimer0 {
    const struct metal_dutimer dutimer;
};

#endif
