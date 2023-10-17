; Basic VIA test
;
; Install VIA card in I/O slot 1, with VIA in lower socket

#include "boot64.inc"


VIA_BASE = $ff90  ; or should it be $FF10?

; VIA access constants

VIA_PORTB = VIA_BASE+0
VIA_PORTA = VIA_BASE+1
VIA_DDRB = VIA_BASE+2
VIA_DDRA = VIA_BASE+3
VIA_T1CL = VIA_BASE+4
VIA_T1CH = VIA_BASE+5
VIA_T1LL = VIA_BASE+6
VIA_T1LH = VIA_BASE+7
VIA_T2CL = VIA_BASE+8
VIA_T2CH = VIA_BASE+9
VIA_SR = VIA_BASE+10
VIA_ACR = VIA_BASE+11
VIA_PCR = VIA_BASE+12
VIA_IFR = VIA_BASE+13
VIA_IER = VIA_BASE+14
VIA_PORTANH = VIA_BASE+15


zp_centis = $20
zp_secs = $21
zp_mins = $22


* = $200

irqentry: jmp irq
nmientry: jmp nmi

entry:
	ldx #$ff : txs

	jsr printimm
	.byte "Checking VIA...", 10, 13, 0

	; Check VIA is present
	lda #$ff : sta VIA_ACR : cmp VIA_ACR : bne novia
	lda #$00 : sta VIA_ACR : cmp VIA_ACR : bne novia

	jsr printimm
	.byte "VIA found", 10, 13, 0

	; Set VIA timer 1 to count continuously
	lda #$40 : sta VIA_ACR

	; Set VIA timer 1 to count down from 8000 - as I/O clock is 8MHz,
	; this will count in milliseconds

	TIMERVAL = 8000-2
	lda #<TIMERVAL : sta VIA_T1CL
	lda #>TIMERVAL : sta VIA_T1CH

	; Zero the counts
	stz zp_centis
	stz zp_secs
	stz zp_mins

	sed : bra loop

novia:
	jsr printimm
	.byte "VIA not found", 10, 13, 0

stop:
	bra stop

loop:

	ldx #10

waitcenti:
	; Clear T1 interrupt flag
	lda #$40 : sta VIA_IFR

waitt1:
	; Wait for timer to expire
	bit VIA_IFR
	bvc waitt1

	dex
	bne waitcenti

	; 1 centisecond has passed
	lda zp_centis : clc : adc #1 : sta zp_centis
	bcc loop

	; 1 second has passed
	lda zp_secs : adc #0 : sta zp_secs
	cmp #$60 : bne display

	; 1 minute has passed
	stz zp_secs
	lda zp_mins : adc #0 : sta zp_mins
	cmp #$60 : bne display

	; 1 hour has passed
	stz zp_mins

display:
	; Display the time
	
	cld

	lda #13 : jsr printchar
	lda zp_mins : jsr printhex
	lda #':' : jsr printchar
	lda zp_secs : jsr printhex

	sed

	bra loop


printhex:
	pha
	ror : ror : ror : ror
	jsr print_nybble
	pla
print_nybble:
.(
	pha
	and #15
	cmp #10
	bmi skipletter
	adc #6
skipletter:
	adc #48
	jsr printchar
	pla
	rts
.)


nmi:
	cld

	jsr printimm
	.byte "NMI", 0

	rti

irq:
	cld
	stz SER_STAT

	jsr printimm
	.byte "IRQ", 0

	rti


codetop:

