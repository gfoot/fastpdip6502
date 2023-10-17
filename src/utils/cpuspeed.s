measurecpuspeed:
.(
	php : sei

	; Disable VIA interrupts
	lda #$7f : STA VIA_IER : sta VIA_IFR

	; Wait for serial system to be idle
waitserialidle:
	bit SER_STAT
	bpl waitserialidle

	; Clear pending serial interrupt
	stz SER_STAT

	; We'll see how many times the CPU can increment a 2-byte BCD number within a certain period of time.
	;
    ; The loop takes 21 cycles to execute.  If we timed for 21ms, the number we get would be the CPU frequency
	; in kHz.  But we can't time for 21ms, as it's outside the range of a VIA timer at 8MHz.  So instead we'll 
	; divide everything by 10, and time for 2.1ms, then the high byte of the resulting count will be the number
	; of MHz and the low byte will be the next two numbers after the decimal point.
	;
	; At 8 MHz I/O clock, 2.1ms is 2.1*8000 = 16800 VIA cycles, and we need to program the VIA with a value 
	; that's 2 lower in order for it to time accurately.
	;
	; We can then run our counting loop indefinitely, and let the VIA interrupt end the loop.

	; CPU speed counter is stored in X:Y.  The code tends to slightly overcount, so round down by reducing the
	; starting value by one (with BCD wrapping) plus another one for the carry that this causes
	ldx #$98
	ldy #$99

	; We want to count in BCD, and start with the carry clear
	sed : clc

	; Set T1 into one-shot mode, and set a high initial count so that it doesn't trigger before we're ready
	lda #$40 : sta VIA_ACR
	lda #$ff : sta VIA_T1CL : sta VIA_T1CH

	; Enable T1 interrupt
	lda #$c0 : sta VIA_IER

	; Set the IRQ vector to point to our code
	lda irqentry+1 : pha
	lda irqentry+2 : pha
	lda #<workloopend : sta irqentry+1
	lda #>workloopend : sta irqentry+2

	jmp pagealign

padding:
paddinglo = <padding
	.dsb 256-paddinglo,$ea
#print *-padding

pagealign:
#print pagealign

	; Reset T1 to the value we want - 16800 ticks (8MHz * 2.1ms) minus 2 for VIA timer latency
	TIMERVAL = 16800-2
	lda #<TIMERVAL : sta VIA_T1CL
	lda #>TIMERVAL : sta VIA_T1CH

workloop:
	; Update count
	txa : adc #1 : tax        ; 7 cycles
	tya : adc #0 : tay        ; 7 cycles

	; Consider an interrupt
	cli : sei                 ; 4 cycles

	bra workloop              ; 3 cycles

	; IRQ handler for exiting workloop
workloopend:
	cld

	; Remove the interrupt frame from the stack
	pla : pla : pla

	; Restore the original IRQ handler
	pla : sta irqentry+2
	pla : sta irqentry+1

	; Disable the VIA interrupts again
	lda #$7f : sta VIA_IER : sta VIA_IFR

	; Restore interrupt disable state and return with result still in X and Y
	plp : rts
.)


printcpuspeed:
	; Push the count, low byte first
	phx : phy

	jsr printimm
	.byte "CPU speed: ", 0

	pla : jsr printhex
	lda #'.' : jsr printchar
	pla : jsr printhex

	jsr printimm
	.byte " MHz", 0

	rts



