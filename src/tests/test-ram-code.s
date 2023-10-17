; RAM code test - copy code to RAM and run it from there
; 
; Expected result - debug port very briefly shows 1 then 2, then starts counting very quickly through all the numbers
;
; Error state 1 - display shows $fd in case of BRK due to bad code execution
;
; Error state 2 - display freezes on a different number due to bad code causing CPU hang

entry:
	ldx #<ramcodebase-1 : txs
	cli

	ldy #payloadsize
copyloop:
	lda payload-1,y : sta ramcodebase-1,y
	dey : bne copyloop

	lda #$f9 : sta DEBUGPORT

	jmp ramentry

irq:
	pha
	lda #$fd : sta DEBUGPORT
	pla
	rti

payload:

* = $8
ramcodebase:

var_count:
	.byte 0

ramentry:

loop0:
	inx : stx DEBUGPORT

loop1:

	ldy #<ramcodeend
loop2:
	tya : clc : adc var_count
	sta 0,y
	iny : bpl loop2

	ldy #<ramcodeend
loop3:
	tya : clc : adc var_count
	cmp 0,y
haltifenotequal: bne haltifenotequal
	iny : bpl loop3

	inc var_count
	bne loop1

	bra loop0

ramcodeend:

payloadsize = ramcodeend-ramcodebase

* = payload + payloadsize

