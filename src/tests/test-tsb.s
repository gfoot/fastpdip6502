; TSB test, since that tends to fail in the Dormann suite
;
; Expected result - debug port counts up, wrapping and looping forever


entry:
	cli
	lda #0 : tax : tay            ; zero all registers

	stz 0 : stz 1 : stz 2

loop:
	lda #$ff : sta $c
	lda #$02 : sta $e

	tsb $c

	ldx $e
	cpx #2
	bne fail

	inc 0
	bne loop
	inc 1
	bne loop
	inc 2
	bpl nooverflow
	stz 2
nooverflow:
	ldx 2
	stx DEBUGPORT
	jmp loop

fail:
	lda 2 : ora #$80 : sta DEBUGPORT
	
stop:
	bra stop

irq:
	lda #$ff : sta DEBUGPORT
	bra irq

