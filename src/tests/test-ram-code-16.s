; RAM code test - copy code to RAM and run it from there
; 
; Expected result - debug port very briefly shows 1 then 2, then starts counting very quickly through all the numbers
;
; Error state 1 - display shows $fd in case of BRK due to bad code execution
;
; Error state 2 - display freezes on a different number due to bad code causing CPU hang

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

* = $7f00
ramcodebase:

var_ptr = $0

var_count:
	.byte 0

ramentry:

loop0:
	inx : stx var_count

	stz var_ptr+1
	stz var_ptr

	ldy #2

	lda #2 : sta DEBUGPORT	

	jmp loop2
loop2:
	sty var_ptr : stz var_ptr
	tya : clc : adc var_count : adc var_ptr+1
	sta (var_ptr),y
	cmp (var_ptr),y : bne loop2fail
	iny : bne loop2
	inc var_ptr+1
	lda var_ptr+1 : cmp #$7f : bne loop2

	stz var_ptr+1
	stz var_ptr

	ldy #2

	lda #3 : sta DEBUGPORT

	jmp loop3
loop3:
	sty var_ptr : stz var_ptr
	tya : clc : adc var_count : adc var_ptr+1
	cmp (var_ptr),y : bne loop3fail
	iny : bne loop3
	inc var_ptr+1
	lda var_ptr+1 : cmp #$7f : bne loop3

	jmp loop0

loop2fail:
	ldx #$82 : stx DEBUGPORT : bra stop

loop3fail:
	ldx #$83 : stx DEBUGPORT

stop:
	bra stop

ramcodeend:

payloadsize = ramcodeend-ramcodebase
#print payloadsize

* = payload + payloadsize

