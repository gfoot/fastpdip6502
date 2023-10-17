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

	jsr printimm
	.byte "All mem test", 13, 10, 0
	
	iny : sty 1 : dey : sty 0
allmeminitloop:
	tya : clc : adc 1 : sta (0),y
	cmp (0),y : bne allmeminitloopfail
	iny : bne allmeminitloop
	inc 1 : bpl allmeminitloop
	
	inx : stx DEBUGPORT  ; 3
	
	dec 1
allmemtestloop:
	tya : clc : adc 1
	cmp (0),y : bne allmemtestloopfail
	dey : bne allmemtestloop
	dec 1 : bne allmemtestloop

	bra again


zpinitloopfail:
	jsr printimm
	.byte "ZP init loop fail", 13, 10, 0
	bra stop

zptestloopfail:
	jsr printimm
	.byte "ZP test loop fail", 13, 10, 0
	bra stop

allmeminitloopfail:
	jsr printimm
	.byte "All mem init loop fail", 13, 10, 0
	bra stop

allmemtestloopfail:
	jsr printimm
	.byte "All mem test loop fail", 13, 10, 0
	bra stop

irq:
stop:
	bra stop

