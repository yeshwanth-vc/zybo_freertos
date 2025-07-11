/******************************************************************************
* Copyright (c) 2010 - 2020 Xilinx, Inc.  All rights reserved.
* SPDX-License-Identifier: MIT
******************************************************************************/
/*****************************************************************************/
/**
* @file boot.S
*
* @addtogroup a9_boot_code Cortex A9 Processor Boot Code
* @{
* <h2> boot.S </h2>
* The boot code performs minimum configuration which is required for an
* application to run starting from processor's reset state. Below is a
* sequence illustrating what all configuration is performed before control
* reaches to main function.
*
* 1. Program vector table base for exception handling
* 2. Invalidate instruction cache, data cache and TLBs
* 3. Program stack pointer for various modes (IRQ, FIQ, supervisor, undefine,
*    abort, system)
* 4. Configure MMU with short descriptor translation table format and program
*    base address of translation table
* 5. Enable data cache, instruction cache and MMU
* 6. Enable Floating point unit
* 7. Transfer control to _start which clears BSS sections, initializes
*    global timer and runs global constructor before jumping to main
*    application
*
* <pre>
* MODIFICATION HISTORY:
*
* Ver   Who     Date     Changes
* ----- ------- -------- ---------------------------------------------------
* 1.00a ecm/sdm 10/20/09 Initial version
* 3.06a sgd     05/15/12 Updated L2CC Auxiliary and Tag RAM Latency control
*			 register settings.
* 3.06a asa 	06/17/12 Modified the TTBR settings and L2 Cache auxiliary
*		         register settings.
* 3.07a asa     07/16/12 Modified the L2 Cache controller settings to improve
*			 performance. Changed the property of the ".boot"
*			 section.
* 3.07a sgd     08/21/12 Modified the L2 Cache controller and cp15 Aux Control
*               Register settings
* 3.09a sgd     02/06/13 Updated SLCR l2c Ram Control register to a
*               value of 0x00020202. Fix for CR 697094 (SI#687034).
* 3.10a srt     04/18/13 Implemented ARM Erratas. Please refer to file
*			 'xil_errata.h' for errata description
* 4.2   pkp	06/19/14 Enabled asynchronous abort exception
* 5.0	pkp	16/15/14 Modified initialization code to enable scu after
*			 MMU is enabled
* 5.1   pkp	05/13/15 Changed the initialization order so to first invalidate
*			 caches and TLB, enable MMU and caches, then enable SMP
*			 bit in ACTLR. L2Cache invalidation and enabling of L2Cache
*			 is done later.
* 5.4   asa     12/6/15  Added code to initialize SPSR for all relevant modes.
* 6.0   mus     08/04/16 Added code to detect zynq-7000 base silicon configuration and
*                        attempt to enable dual core behavior on single cpu zynq-7000s
*                        devices is prevented from corrupting system behavior.
* 6.0   mus     08/24/16 Check CPU core before putting cpu1 to reset for single core
*                        zynq-7000s devices
*
* </pre>
*
* @note
*
* None.
*
******************************************************************************/

#include "xparameters.h"
#include "xil_errata.h"

.globl MMUTable
.global _prestart
.global _boot
.global __stack
.global __irq_stack
.global __supervisor_stack
.global __abort_stack
.global __fiq_stack
.global __undef_stack
.global _vector_table

.set PSS_L2CC_BASE_ADDR, 0xF8F02000
.set PSS_SLCR_BASE_ADDR, 0xF8000000

.set RESERVED,		0x0fffff00
.set TblBase ,		MMUTable
.set LRemap,		0xFE00000F		/* set the base address of the peripheral block as not shared */
.set L2CCWay,		(PSS_L2CC_BASE_ADDR + 0x077C)	/*(PSS_L2CC_BASE_ADDR + PSS_L2CC_CACHE_INVLD_WAY_OFFSET)*/
.set L2CCSync,		(PSS_L2CC_BASE_ADDR + 0x0730)	/*(PSS_L2CC_BASE_ADDR + PSS_L2CC_CACHE_SYNC_OFFSET)*/
.set L2CCCrtl,		(PSS_L2CC_BASE_ADDR + 0x0100)	/*(PSS_L2CC_BASE_ADDR + PSS_L2CC_CNTRL_OFFSET)*/
.set L2CCAuxCrtl,	(PSS_L2CC_BASE_ADDR + 0x0104)	/*(PSS_L2CC_BASE_ADDR + XPSS_L2CC_AUX_CNTRL_OFFSET)*/
.set L2CCTAGLatReg,	(PSS_L2CC_BASE_ADDR + 0x0108)	/*(PSS_L2CC_BASE_ADDR + XPSS_L2CC_TAG_RAM_CNTRL_OFFSET)*/
.set L2CCDataLatReg,	(PSS_L2CC_BASE_ADDR + 0x010C)	/*(PSS_L2CC_BASE_ADDR + XPSS_L2CC_DATA_RAM_CNTRL_OFFSET)*/
.set L2CCIntClear,	(PSS_L2CC_BASE_ADDR + 0x0220)	/*(PSS_L2CC_BASE_ADDR + XPSS_L2CC_IAR_OFFSET)*/
.set L2CCIntRaw,	(PSS_L2CC_BASE_ADDR + 0x021C)	/*(PSS_L2CC_BASE_ADDR + XPSS_L2CC_ISR_OFFSET)*/

.set SLCRlockReg,	    (PSS_SLCR_BASE_ADDR + 0x04)	/*(PSS_SLCR_BASE_ADDR + XPSS_SLCR_LOCK_OFFSET)*/
.set SLCRUnlockReg,     (PSS_SLCR_BASE_ADDR + 0x08)	/*(PSS_SLCR_BASE_ADDR + XPSS_SLCR_UNLOCK_OFFSET)*/
.set SLCRL2cRamReg,     (PSS_SLCR_BASE_ADDR + 0xA1C) /*(PSS_SLCR_BASE_ADDR + XPSS_SLCR_L2C_RAM_OFFSET)*/
.set SLCRCPURSTReg,     (0xF8000000 + 0x244)           /*(XPS_SYS_CTRL_BASEADDR + A9_CPU_RST_CTRL_OFFSET)*/
.set EFUSEStaus,        (0xF800D000 + 0x10)            /*(XPS_EFUSE_BASEADDR + EFUSE_STATUS_OFFSET)*/

/* workaround for simulation not working when L1 D and I caches,MMU and  L2 cache enabled - DT568997 */
.if SIM_MODE == 1
.set CRValMmuCac,	0b00000000000000	/* Disable IDC, and MMU */
.else
.set CRValMmuCac,	0b01000000000101	/* Enable IDC, and MMU */
.endif

.set CRValHiVectorAddr,	0b10000000000000	/* Set the Vector address to high, 0xFFFF0000 */

.set L2CCAuxControl,	0x72360000		/* Enable all prefetching, Cache replacement policy, Parity enable,
                                        Event monitor bus enable and Way Size (64 KB) */
.set L2CCControl,	0x01			/* Enable L2CC */
.set L2CCTAGLatency,	0x0111			/* latency for TAG RAM */
.set L2CCDataLatency,	0x0121			/* latency for DATA RAM */

.set SLCRlockKey,	        0x767B			/* SLCR lock key */
.set SLCRUnlockKey,	        0xDF0D			/* SLCR unlock key */
.set SLCRL2cRamConfig,      0x00020202      /* SLCR L2C ram configuration */

/* Stack Pointer locations for boot code */
.set Undef_stack,	__undef_stack
.set FIQ_stack,		__fiq_stack
.set Abort_stack,	__abort_stack
.set SPV_stack,		__supervisor_stack
.set IRQ_stack,		__irq_stack
.set SYS_stack,		__stack

.set vector_base,	_vector_table

.set FPEXC_EN,		0x40000000		/* FPU enable bit, (1 << 30) */

.section .boot,"ax"


/* this initializes the various processor modes */

_prestart:
_boot:

#if XPAR_CPU_ID==0
        /* only allow cpu0 through */
	mrc	p15,0,r1,c0,c0,5
	and	r1, r1, #0xf
        cmp	r1, #0
	beq	CheckEFUSE
	EndlessLoop0:
		wfe
	b	EndlessLoop0

CheckEFUSE:
        ldr r0,=EFUSEStaus
        ldr r1,[r0]                             /* Read eFuse setting */
        ands r1,r1,#0x80                        /* Check whether device is having single core */
	beq OKToRun

 /* single core device, reset cpu1 */
        ldr     r0,=SLCRUnlockReg               /* Load SLCR base address base + unlock register */
        ldr     r1,=SLCRUnlockKey               /* set unlock key */
        str     r1, [r0]                        /* Unlock SLCR */

	ldr r0,=SLCRCPURSTReg
	ldr r1,[r0]                             /* Read CPU Software Reset Control register */
	orr r1,r1,#0x22
        str r1,[r0]                             /* Reset CPU1 */

        ldr	r0,=SLCRlockReg         	/* Load SLCR base address base + lock register */
	ldr	r1,=SLCRlockKey	        	/* set lock key */
	str	r1, [r0]	        	/* lock SLCR */

#elif XPAR_CPU_ID==1
	/* only allow cpu1 through */
       mrc	p15,0,r1,c0,c0,5
       and	r1, r1, #0xf
       cmp	r1, #1
       beq	CheckEFUSE1
       b        EndlessLoop1

CheckEFUSE1:
        ldr r0,=EFUSEStaus
        ldr r1,[r0]                             /* Read eFuse setting */
        ands r1,r1,#0x80                        /* Check whether device is having single core */
	beq OKToRun
	EndlessLoop1:
	        wfe
	b	EndlessLoop1
#endif

OKToRun:
	mrc     p15, 0, r0, c0, c0, 0		/* Get the revision */
	and     r5, r0, #0x00f00000
	and     r6, r0, #0x0000000f
	orr     r6, r6, r5, lsr #20-4

#ifdef CONFIG_ARM_ERRATA_742230
        cmp     r6, #0x22                       /* only present up to r2p2 */
        mrcle   p15, 0, r10, c15, c0, 1         /* read diagnostic register */
        orrle   r10, r10, #1 << 4               /* set bit #4 */
        mcrle   p15, 0, r10, c15, c0, 1         /* write diagnostic register */
#endif

#ifdef CONFIG_ARM_ERRATA_743622
	teq     r5, #0x00200000                 /* only present in r2p* */
	mrceq   p15, 0, r10, c15, c0, 1         /* read diagnostic register */
	orreq   r10, r10, #1 << 6               /* set bit #6 */
	mcreq   p15, 0, r10, c15, c0, 1         /* write diagnostic register */
#endif

	/* set VBAR to the _vector_table address in linker script */
	ldr	r0, =vector_base
	mcr	p15, 0, r0, c12, c0, 0

	/*invalidate scu*/
	ldr	r7, =0xf8f0000c
	ldr	r6, =0xffff
	str	r6, [r7]

	/* Invalidate caches and TLBs */
	mov	r0,#0				/* r0 = 0  */
	mcr	p15, 0, r0, c8, c7, 0		/* invalidate TLBs */
	mcr	p15, 0, r0, c7, c5, 0		/* invalidate icache */
	mcr	p15, 0, r0, c7, c5, 6		/* Invalidate branch predictor array */
	bl	invalidate_dcache		/* invalidate dcache */

	/* Disable MMU, if enabled */
	mrc	p15, 0, r0, c1, c0, 0		/* read CP15 register 1 */
	bic	r0, r0, #0x1			/* clear bit 0 */
	mcr	p15, 0, r0, c1, c0, 0		/* write value back */

#ifdef SHAREABLE_DDR
	/* Mark the entire DDR memory as shareable */
	ldr	r3, =0x3ff			/* 1024 entries to cover 1G DDR */
	ldr	r0, =TblBase			/* MMU Table address in memory */
	ldr	r2, =0x15de6			/* S=b1 TEX=b101 AP=b11, Domain=b1111, C=b0, B=b1 */
shareable_loop:
	str	r2, [r0]			/* write the entry to MMU table */
	add	r0, r0, #0x4			/* next entry in the table */
	add	r2, r2, #0x100000		/* next section */
	subs	r3, r3, #1
	bge	shareable_loop			/* loop till 1G is covered */
#endif

	mrs	r0, cpsr			/* get the current PSR */
	mvn	r1, #0x1f			/* set up the irq stack pointer */
	and	r2, r1, r0
	orr	r2, r2, #0x12			/* IRQ mode */
	msr	cpsr, r2
	ldr	r13,=IRQ_stack			/* IRQ stack pointer */
	bic r2, r2, #(0x1 << 9)    		 /* Set EE bit to little-endian */
	msr spsr_fsxc,r2

	mrs	r0, cpsr			/* get the current PSR */
	mvn	r1, #0x1f			/* set up the supervisor stack pointer */
	and	r2, r1, r0
	orr	r2, r2, #0x13			/* supervisor mode */
	msr	cpsr, r2
	ldr	r13,=SPV_stack			/* Supervisor stack pointer */
	bic r2, r2, #(0x1 << 9)     		/* Set EE bit to little-endian */
	msr spsr_fsxc,r2

	mrs	r0, cpsr			/* get the current PSR */
	mvn	r1, #0x1f			/* set up the Abort  stack pointer */
	and	r2, r1, r0
	orr	r2, r2, #0x17			/* Abort mode */
	msr	cpsr, r2
	ldr	r13,=Abort_stack		/* Abort stack pointer */
	bic r2, r2, #(0x1 << 9)     		/* Set EE bit to little-endian */
	msr spsr_fsxc,r2

	mrs	r0, cpsr			/* get the current PSR */
	mvn	r1, #0x1f			/* set up the FIQ stack pointer */
	and	r2, r1, r0
	orr	r2, r2, #0x11			/* FIQ mode */
	msr	cpsr, r2
	ldr	r13,=FIQ_stack			/* FIQ stack pointer */
	bic r2, r2, #(0x1 << 9)    		/* Set EE bit to little-endian */
	msr spsr_fsxc,r2

	mrs	r0, cpsr			/* get the current PSR */
	mvn	r1, #0x1f			/* set up the Undefine stack pointer */
	and	r2, r1, r0
	orr	r2, r2, #0x1b			/* Undefine mode */
	msr	cpsr, r2
	ldr	r13,=Undef_stack		/* Undefine stack pointer */
	bic r2, r2, #(0x1 << 9)     		/* Set EE bit to little-endian */
	msr spsr_fsxc,r2

	mrs	r0, cpsr			/* get the current PSR */
	mvn	r1, #0x1f			/* set up the system stack pointer */
	and	r2, r1, r0
	orr	r2, r2, #0x1F			/* SYS mode */
	msr	cpsr, r2
	ldr	r13,=SYS_stack			/* SYS stack pointer */

	/*set scu enable bit in scu*/
	ldr	r7, =0xf8f00000
	ldr	r0, [r7]
	orr	r0, r0, #0x1
	str	r0, [r7]

	/* enable MMU and cache */

	ldr	r0,=TblBase			/* Load MMU translation table base */
	orr	r0, r0, #0x5B			/* Outer-cacheable, WB */
	mcr	15, 0, r0, c2, c0, 0		/* TTB0 */

	mvn	r0,#0				/* Load MMU domains -- all ones=manager */
	mcr	p15,0,r0,c3,c0,0

	/* Enable mmu, icahce and dcache */
	ldr	r0,=CRValMmuCac
	mcr	p15,0,r0,c1,c0,0		/* Enable cache and MMU */
	dsb					/* dsb	allow the MMU to start up */
	isb					/* isb	flush prefetch buffer */

	/* Write to ACTLR */
	mrc	p15, 0, r0, c1, c0, 1		/* Read ACTLR*/
	orr	r0, r0, #(0x01 << 6)		/* set SMP bit */
	orr	r0, r0, #(0x01 )		/* Cache/TLB maintenance broadcast */
	mcr	p15, 0, r0, c1, c0, 1		/* Write ACTLR*/

/* Invalidate L2 Cache and enable L2 Cache*/
/* For AMP, assume running on CPU1. Don't initialize L2 Cache (up to Linux) */
#if USE_AMP!=1
	ldr	r0,=L2CCCrtl			/* Load L2CC base address base + control register */
	mov	r1, #0				/* force the disable bit */
	str	r1, [r0]			/* disable the L2 Caches */

	ldr	r0,=L2CCAuxCrtl			/* Load L2CC base address base + Aux control register */
	ldr	r1,[r0]				/* read the register */
	ldr	r2,=L2CCAuxControl		/* set the default bits */
	orr	r1,r1,r2
	str	r1, [r0]			/* store the Aux Control Register */

	ldr	r0,=L2CCTAGLatReg		/* Load L2CC base address base + TAG Latency address */
	ldr	r1,=L2CCTAGLatency		/* set the latencies for the TAG*/
	str	r1, [r0]			/* store the TAG Latency register Register */

	ldr	r0,=L2CCDataLatReg		/* Load L2CC base address base + Data Latency address */
	ldr	r1,=L2CCDataLatency		/* set the latencies for the Data*/
	str	r1, [r0]			/* store the Data Latency register Register */

	ldr	r0,=L2CCWay			/* Load L2CC base address base + way register*/
	ldr	r2, =0xFFFF
	str	r2, [r0]			/* force invalidate */

	ldr	r0,=L2CCSync			/* need to poll 0x730, PSS_L2CC_CACHE_SYNC_OFFSET */
						/* Load L2CC base address base + sync register*/
	/* poll for completion */
Sync:	ldr	r1, [r0]
	cmp	r1, #0
	bne	Sync

	ldr	r0,=L2CCIntRaw			/* clear pending interrupts */
	ldr	r1,[r0]
	ldr	r0,=L2CCIntClear
	str	r1,[r0]

	ldr	r0,=SLCRUnlockReg		/* Load SLCR base address base + unlock register */
	ldr	r1,=SLCRUnlockKey	    	/* set unlock key */
	str	r1, [r0]		    	/* Unlock SLCR */

	ldr	r0,=SLCRL2cRamReg		/* Load SLCR base address base + l2c Ram Control register */
	ldr	r1,=SLCRL2cRamConfig        	/* set the configuration value */
	str	r1, [r0]	        	/* store the L2c Ram Control Register */

	ldr	r0,=SLCRlockReg         	/* Load SLCR base address base + lock register */
	ldr	r1,=SLCRlockKey	        	/* set lock key */
	str	r1, [r0]	        	/* lock SLCR */

	ldr	r0,=L2CCCrtl			/* Load L2CC base address base + control register */
	ldr	r1,[r0]				/* read the register */
	mov	r2, #L2CCControl		/* set the enable bit */
	orr	r1,r1,r2
	str	r1, [r0]			/* enable the L2 Caches */
#endif

	mov	r0, r0
	mrc	p15, 0, r1, c1, c0, 2		/* read cp access control register (CACR) into r1 */
	orr	r1, r1, #(0xf << 20)		/* enable full access for p10 & p11 */
	mcr	p15, 0, r1, c1, c0, 2		/* write back into CACR */

	/* enable vfp */
	fmrx	r1, FPEXC			/* read the exception register */
	orr	r1,r1, #FPEXC_EN		/* set VFP enable bit, leave the others in orig state */
	fmxr	FPEXC, r1			/* write back the exception register */

	mrc	p15,0,r0,c1,c0,0		/* flow prediction enable */
	orr	r0, r0, #(0x01 << 11)		/* #0x8000 */
	mcr	p15,0,r0,c1,c0,0

	mrc	p15,0,r0,c1,c0,1		/* read Auxiliary Control Register */
	orr	r0, r0, #(0x1 << 2)		/* enable Dside prefetch */
	orr	r0, r0, #(0x1 << 1)		/* enable L2 Prefetch hint */
	mcr	p15,0,r0,c1,c0,1		/* write Auxiliary Control Register */

	mrs	r0, cpsr			/* get the current PSR */
	bic	r0, r0, #0x100			/* enable asynchronous abort exception */
	msr	cpsr_xsf, r0


	b	_start			/* jump to C startup code */
	and	r0, r0, r0			/* no op */

.Ldone:	b	.Ldone				/* Paranoia: we should never get here */


/*
 *************************************************************************
 *
 * invalidate_dcache - invalidate the entire d-cache by set/way
 *
 * Note: for Cortex-A9, there is no cp instruction for invalidating
 * the whole D-cache. Need to invalidate each line.
 *
 *************************************************************************
 */
invalidate_dcache:
	mrc	p15, 1, r0, c0, c0, 1		/* read CLIDR */
	ands	r3, r0, #0x7000000
	mov	r3, r3, lsr #23			/* cache level value (naturally aligned) */
	beq	finished
	mov	r10, #0				/* start with level 0 */
loop1:
	add	r2, r10, r10, lsr #1		/* work out 3xcachelevel */
	mov	r1, r0, lsr r2			/* bottom 3 bits are the Cache type for this level */
	and	r1, r1, #7			/* get those 3 bits alone */
	cmp	r1, #2
	blt	skip				/* no cache or only instruction cache at this level */
	mcr	p15, 2, r10, c0, c0, 0		/* write the Cache Size selection register */
	isb					/* isb to sync the change to the CacheSizeID reg */
	mrc	p15, 1, r1, c0, c0, 0		/* reads current Cache Size ID register */
	and	r2, r1, #7			/* extract the line length field */
	add	r2, r2, #4			/* add 4 for the line length offset (log2 16 bytes) */
	ldr	r4, =0x3ff
	ands	r4, r4, r1, lsr #3		/* r4 is the max number on the way size (right aligned) */
	clz	r5, r4				/* r5 is the bit position of the way size increment */
	ldr	r7, =0x7fff
	ands	r7, r7, r1, lsr #13		/* r7 is the max number of the index size (right aligned) */
loop2:
	mov	r9, r4				/* r9 working copy of the max way size (right aligned) */
loop3:
	orr	r11, r10, r9, lsl r5		/* factor in the way number and cache number into r11 */
	orr	r11, r11, r7, lsl r2		/* factor in the index number */
	mcr	p15, 0, r11, c7, c6, 2		/* invalidate by set/way */
	subs	r9, r9, #1			/* decrement the way number */
	bge	loop3
	subs	r7, r7, #1			/* decrement the index */
	bge	loop2
skip:
	add	r10, r10, #2			/* increment the cache number */
	cmp	r3, r10
	bgt	loop1

finished:
	mov	r10, #0				/* switch back to cache level 0 */
	mcr	p15, 2, r10, c0, c0, 0		/* select current cache level in cssr */
	dsb
	isb

	bx	lr

.end
/**
* @} End of "addtogroup a9_boot_code".
*/
