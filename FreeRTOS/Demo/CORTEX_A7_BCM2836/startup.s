.extern	system_init
.extern __bss_start
.extern __bss_end
.extern FreeRTOS_IRQ_Handler
.extern FreeRTOS_SVC_Handler    
.extern rpi_cpu_irq_disable
.extern main
	.section .init
	.globl _start
;; 
_start:
	;@ All the following instruction should be read as:
	;@ Load the address at symbol into the program counter.
	
	ldr	pc,reset_handler		;@ 	Processor Reset handler 		-- we will have to force this on the raspi!
	;@ Because this is the first instruction executed, of cause it causes an immediate branch into reset!
	
	ldr pc,undefined_handler	;@ 	Undefined instruction handler 	-- processors that don't have thumb can emulate thumb!
    ldr pc,swi_handler			;@ 	Software interrupt / TRAP (SVC) -- system SVC handler for switching to kernel mode.
    ldr pc,prefetch_handler		;@ 	Prefetch/abort handler.
    ldr pc,data_handler			;@ 	Data abort handler/
    ldr pc,unused_handler		;@ 	-- Historical from 26-bit addressing ARMs -- was invalid address handler.
    ldr pc,irq_handler			;@ 	IRQ handler
    ldr pc,fiq_handler			;@ 	Fast interrupt handler.

	;@ Here we create an exception address table! This means that reset/hang/irq can be absolute addresses
reset_handler:      .word reset
undefined_handler:  .word undefined_instruction
swi_handler:        .word FreeRTOS_SVC_Handler
prefetch_handler:   .word prefetch_abort
data_handler:       .word data_abort
unused_handler:     .word unused
irq_handler:        .word FreeRTOS_IRQ_Handler
fiq_handler:        .word fiq

reset:
	mrc     p15, 0, r1, c0, c0, 5
	and     r1, r1, #3
	cmp r1, #0
	beq zero
	// cpu id > 0, stop
not_zero:
	wfe
	b       not_zero
zero:// cpu id == 0

	/* Disable IRQ & FIQ */
	cpsid if

	mov r0, #0x1
	mcr p15, 0, r0, c9, c14, 0 /* allow PMU from user space */

	// PMCR.E (bit 0) = 1
	mcr p15, 0, r0, c9, c12, 0

	// PMCNTENSET.C (bit 31) = 1
	mov r0, #0x80000000
	mcr p15, 0, r0, c9, c12, 1

	/* Disable IRQ & FIQ */
	cpsid if

	/* Check for HYP mode */
	mrs r0, cpsr_all
	and r0, r0, #0x1F
	mov r8, #0x1A
	cmp r0, r8
	beq overHyped
	b continueBoot

overHyped: /* Get out of HYP mode */
	ldr r1, =continueBoot
	msr ELR_hyp, r1
	mrs r1, cpsr_all
	and r1, r1, #0x1f	;@ CPSR_MODE_MASK
	orr r1, r1, #0x13	;@ CPSR_MODE_SUPERVISOR
	msr SPSR_hyp, r1
	eret

continueBoot:
	;@	In the reset handler, we need to copy our interrupt vector table to 0x0000, its currently at 0x8000

	// R0 = System Control Register
	mrc p15,0,r0,c1,c0,0

	// Enable caches and branch prediction
	orr r0, #0x800
	orr r0, #0x4
	orr r0, #0x1000

	// System Control Register = R0
	mcr p15,0,r0,c1,c0,0

	mov r0,#0x8000								;@ Store the source pointer
    mov r1,#0x0000								;@ Store the destination pointer.

	;@	Here we copy the branching instructions
    ldmia r0!,{r2,r3,r4,r5,r6,r7,r8,r9}			;@ Load multiple values from indexed address. 		; Auto-increment R0
    stmia r1!,{r2,r3,r4,r5,r6,r7,r8,r9}			;@ Store multiple values from the indexed address.	; Auto-increment R1

	;@	So the branches get the correct address we also need to copy our vector table!
    ldmia r0!,{r2,r3,r4,r5,r6,r7,r8,r9}			;@ Load from 4*n of regs (8) as R0 is now incremented.
    stmia r1!,{r2,r3,r4,r5,r6,r7,r8,r9}			;@ Store this extra set of data.


	;@	Set up the various STACK pointers for different CPU modes
    ;@ (PSR_IRQ_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
    mov r0,#0xD2
    msr cpsr_c,r0
    mov sp,#0x8000

    ;@ (PSR_FIQ_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
    mov r0,#0xD1
    msr cpsr_c,r0
    mov sp,#0x4000

    ;@ (PSR_SVC_MODE|PSR_FIQ_DIS|PSR_IRQ_DIS)
    mov r0,#0xD3
    msr cpsr_c,r0
	mov sp,#0x8000000

	ldr r0, =__bss_start
	ldr r1, =__bss_end

	mov r2, #0

zero_loop:
	cmp 	r0,r1
	it		lt
	strlt	r2,[r0], #4
	blt		zero_loop

	bl 		rpi_cpu_irq_disable
	
	
	;@ 	mov	sp,#0x1000000
	b main									;@ We're ready?? Lets start main execution!
	.section .text

undefined_instruction:
	b undefined_instruction

prefetch_abort:
	b prefetch_abort

data_abort:
	b data_abort

unused:
	b unused

fiq:
	b fiq
	
hang:
	b hang

.globl PUT32
PUT32:
    str r1,[r0]
    bx lr

.globl GET32
GET32:
    ldr r0,[r0]
    bx lr

.globl dummy
dummy:
    bx lr
