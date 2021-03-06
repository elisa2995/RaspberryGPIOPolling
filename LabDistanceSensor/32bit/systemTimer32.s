@ systemTimer32.s
@ Implements functionalities to handle the system timer
@ of the Raspberry Pi

@ Define my Raspberry Pi
        .cpu    cortex-a53
        .fpu    neon-fp-armv8
        .syntax unified         	@ modern syntax

@ Constants for assembler
        .equ    PERIPH,0x3f000000   	@ RPi 2 & 3 peripherals
        .equ    TIMER_OFFSET,0x3000     @ system timer offset
	.equ	CLO_OFFSET, 4		@ system timer counter offset from beginning of timer regs

@ Defined by us:
	.equ    PAGE_SIZE,4096  @ Raspbian memory page
@ Program variables
	.data
fileDesc:
	.word	0
progMem:
	.word	0

@ The program
        .text
        .align  2
        .global getTimestamp
	.global getElapsedTime
	.global initTimer
	.global closeTimer

@ Constant program data
        .section .rodata
        .align  2
device:
        .asciz  "/dev/mem"
devErr:
        .asciz  "Cannot open /dev/mem\n"
memErr:
        .asciz  "Cannot map /dev/mem\n"

@ iniTimer
@ Maps the timer registers to a main memory location so we can 
@ access them.
@ Calling sequence:
@	bl initTimer
@
initTimer:
	push 	{r4, lr}

@ Open /dev/mem for read/write and syncing        
        ldr     r0, deviceAddr  		@ address of /dev/mem
        bl	openRWSync
        cmp     r0, -1          		@ check for error
        bne     memTOK       			@ no error, continue
        ldr     r0, devErrAddr  		@ error, tell user
        bl      printf
        b       allDone         		@ and end program

memTOK: 
@Save the file descriptor
	ldr	r4, fileDescAddr
	str	r0, [r4]			@ r0 contains the file descriptor (returned by open)

@ Map the timer
	ldr	r1, timerAddrPtr 		@ r1 is a pointer to the timer address
	bl     	mapMemory
        cmp     r0, -1          		@ check for error
        bne     mmapTOK         		@ no error, continue
        ldr     r0, memErrAddr 			@ error, tell user
        bl      printf			
        b       closeTDev       		@ and close /dev/mem

@ Save the address of the mapping memory in an internal variable
mmapTOK:
	ldr		r1, progMemAddr
	str		r0, [r1]    
	b		allDone

closeTDev:
        mov     r0, r4          		@ /dev/mem file descriptor
        bl      close	        		@ close the file   
allDone:
	pop		{r4, lr}		
	bx		lr
																		  
@ getTimestamp
@ Returns the current timestamp
@ Calling sequence:
@       bl getTimestamp
@ Output:
@		r0 <- lowest 4 bytes of system time(us)
@		r1 <- highest 4 bytes of system time(us)
getTimestamp:
       	ldr	r0, progMemAddr			@ pointer to the address of TIMER regs
	ldr	r0, [r0]			@ address of TIMER regs
	ldrd	r0, r1, [r0, #CLO_OFFSET]
        bx      lr              		@ return

@ getElapsedTime
@ Returns the us that elapsed between the two timestamp in input.
@ Calling sequence:
@		r0 <- lower 4 bytes of the first timestamp (us)  - the farthest one
@		r1 <- highest 4 bytes of the first timestamp (us) 
@		r2 <- lowest 4 bytes of the second timestamp (us) - the closest one
@		r3 <- highest 4 bytes of the second timestamp (us)
@		bl getElapsedTime
@ Output:
@		r0 <- lowest 4 bytes of the elapsed time (us)
@		r1 <- highest 4 bytes of the elapsed time (us)
getElapsedTime:
	subs	r0, r2, r0				@ subtract the lower part of the two timestamps
	sbc	r1, r3, r1				@ subtract the higher part of the two timestamps, 
							@ eventually subtracting the borrow generated by the previous sub
	bx	lr

@ closeTimer
@ Unmaps the timer memory and closes the device
@ Calling sequence:
@		bl closeTimer
closeTimer:
	push	{r4, lr}
	ldr 	r0, progMemAddr
	ldr 	r0, [r0]				@ address of the mapped memory
	ldr 	r1, fileDescAddr
	ldr 	r1, [r1]				@ file descriptor
	bl	closeDevice

	pop	{r4, lr}
	bx 	lr

deviceAddr:
        .word   device
devErrAddr:
        .word   devErr
memErrAddr:
        .word   memErr
timerAddrPtr:
	.word  	PERIPH+TIMER_OFFSET
fileDescAddr:
	.word fileDesc
progMemAddr:
	.word	progMem
