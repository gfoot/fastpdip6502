; RAM-based TSB test - see also test-tsb.s

entry:
	ldx #$ff : txs
	cli

	ldy #payloadsize
copyloop:
	lda payload-1,y : sta ramcodebase-1,y
	dey : bne copyloop

	lda #1 : sta DEBUGPORT

	jmp ramentry

irq:
	pha
	lda #$fd : sta DEBUGPORT
	pla
	rti

payload:

;* = $7eea
* = $7f03
ramcodebase:

var_ptr = $0

var_count:
	.byte 0

ramentry:
	lda #0 : tax : tay            ; zero all registers

	stz 0 : stz 1 : stz 2

loop:
	lda #$20 : sta $c
	lda #$02 : sta $e
	lda #$df

	tsb $c

	ldx $e
	cpx #$02
	bne fail

	inc 0 : bne loop
	inc 1 : bne loop
	inc 2 : bpl nooverflow : stz 2
nooverflow:
	ldx 2 : stx DEBUGPORT
	jmp loop

fail:
	lda 2 : ora #$80 : sta DEBUGPORT
	
stop:
	bra stop

ramcodeend:

payloadsize = ramcodeend-ramcodebase
#print payloadsize

* = payload + payloadsize

