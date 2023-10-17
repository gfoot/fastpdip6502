; CPU speed reporting test

#include "boot64.inc"

#include "utils/via.s"


* = $200

irqentry: jmp irq
nmientry: jmp nmi

entry:
	ldx #$ff : txs

	jsr checkvia

	jsr printimm
	.byte 10,"Measuring CPU speed", 10, 10, 13, 0

loop:
	jsr measurecpuspeed
	lda #13 : jsr printchar
	jsr printcpuspeed
	bra loop


checkvia:
	jsr printimm
	.byte "Checking VIA...", 10, 13, 0

	; Check VIA is present at the expected address
	lda #$ff : sta VIA_ACR : cmp VIA_ACR : bne novia
	lda #$00 : sta VIA_ACR : cmp VIA_ACR : bne novia

	jsr printimm
	.byte "VIA found", 10, 13, 0
	rts

novia:
	jsr printimm
	.byte "VIA not found", 10, 13, 0

stop:
	bra stop

	
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

#include "utils/cpuspeed.s"
#include "utils/print.s"

codetop:

