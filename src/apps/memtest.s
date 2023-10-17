; 64K memory test

#include "boot64.inc"

* = $200

irqentry: jmp irq
nmientry: jmp nmi

entry:
	ldx #$ff : txs

again:
	inx : stx DEBUGPORT  ; 0

	jsr printimm
	.byte "ZP test", 13, 10, 0
	
	ldy #0
zpinitloop:
	tya : clc : adc #17 : sta 0,y
	cmp 0,y : bne zpinitloopfail
	iny : bne zpinitloop

	inx : stx DEBUGPORT  ; 1

	ldy #0
zptestloop:
	tya : clc : adc #17
	cmp 0,y : bne zptestloopfail
	dey : bne zptestloop

	inx : stx DEBUGPORT  ; 2

	lda #17 : sta 2
	lda #87 : sta 3

	lda #$80 : sta $8000
	lsr : sta $0
	asl : cmp $8000 : bne lowonly
	lsr : lsr : sta $8000
	asl : cmp $0 : bne lowonly
	lsr : cmp $8000 : bne lowonly

	jsr printimm
	.byte "64K mode", 13, 10, 0

	jsr lowmeminit
	jsr lowmemtest
	bra test64k

zpinitloopfail:
	jsr printimm
	.byte "ZP init loop fail", 13, 10, 0
	bra stop

zptestloopfail:
	jsr printimm
	.byte "ZP test loop fail", 13, 10, 0
	bra stop

stop:
	bra stop



lowonly:
	jsr printimm
	.byte "32K mode", 13, 10, 0

test32k:
	jsr lowmeminit
	jsr lowmemtest
	bra test32k



test64k:
	jsr highmeminit
	jsr lowmemtest
	jsr lowmeminit
	jsr highmemtest
	bra test64k


lowmeminit:
	jsr printimm
	.byte "Low mem init", 13, 10, 0
	
	inx : stx DEBUGPORT

	inc 2

	ldy #>codetop+256 : sty 1 : ldy #0 : sty 0
lowmeminitloop:
	tya : clc : adc 1 : adc 2 : sta (0),y
	cmp (0),y : bne lowmeminitloopfail
	iny : bne lowmeminitloop
	inc 1 : bpl lowmeminitloop
	
	rts


lowmemtest:
	jsr printimm
	.byte "Low mem test", 13, 10, 0

	inx : stx DEBUGPORT

	ldy #$7f : sty 1 : ldy #0 : sty 0
lowmemtestloop:
	tya : clc : adc 1 : adc 2
	cmp (0),y : bne lowmemtestloopfail
	dey : bne lowmemtestloop
	dec 1 : lda 1 : cmp #>codetop : bne lowmemtestloop

	rts


lowmeminitloopfail:
	jsr printimm
	.byte "Low mem init loop fail", 13, 10, 0
	bra stop2

lowmemtestloopfail:
	jsr printimm
	.byte "Low mem test loop fail", 13, 10, 0
	bra stop2

stop2:
	bra stop2


highmeminit:
	jsr printimm
	.byte "High mem init", 13, 10, 0

	inx : stx DEBUGPORT

	inc 3

	ldy #>codetop+$8100 : sty 1 : ldy #0 : sty 0
highmeminitloop:
	tya : clc : adc 1 : adc 3 : sta (0),y
	cmp (0),y : bne highmeminitloopfail
	iny : bne highmeminitloop
	inc 1 : lda 1 : cmp #$fe : bne highmeminitloop

	rts

highmemtest:

	jsr printimm
	.byte "High mem test", 13, 10, 0
	inx : stx DEBUGPORT  ; 5

	ldy #$fd : sty 1 : ldy #0 : sty 0
highmemtestloop:
	tya : clc : adc 1 : adc 3
	cmp (0),y : bne highmemtestloopfail
	dey : bne highmemtestloop
	dec 1 : lda 1 : cmp #>codetop+$8000 : bne highmemtestloop

	rts


highmeminitloopfail:
	jsr printimm
	.byte "High mem init loop fail", 13, 10, 0
	bra stop3

highmemtestloopfail:
	jsr printimm
	.byte "High mem test loop fail", 13, 10, 0
	bra stop3

stop3:
	bra stop3

nmi:
	jsr printimm
	.byte "NMI", 0
	rti

irq:
	bit $ff50
	rti


codetop:

