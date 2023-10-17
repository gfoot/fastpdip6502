; IRQ handling
;
; Currently only serial interface interrupts are handled


irq_init:
	stz zp_stray_interrupts

	; Disable VIA interrupts and clear flags
	lda #$7f : sta VIA_IER : sta VIA_IFR

	cli

	rts


&irq:
.(
	pha

	; Clear any pending serial interrupt, as we're processing it now
	stz SER_STAT

	; Check for serial system interrupt - bits 6 and 7 are relevant
	lda SER_STAT
	and #$c0
	beq notserial

	jsr serialout_tick

notserial:
	; Maybe a VIA interrupt, not using those at the moment though
	
	pla : rti
.)

