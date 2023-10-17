* = $200

#include "boot64.inc"

irqentry: jmp irq
nmientry: jmp nmi

entry:
	jsr printimm
	.byte "Hello world!\r\n\n", 0

countloop:
	iny : bne countloop
	inc : bne countloop
	inx : stx DEBUGPORT : bra countloop

irq:
	jsr printimm
	.byte "IRQ", 0
	rti

nmi:
	jsr printimm
	.byte "NMI", 0
	rti

