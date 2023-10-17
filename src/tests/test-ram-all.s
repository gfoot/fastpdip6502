; RAM test - check we can write and read back all RAM locations independently
;
; Expected result - debug port shows 1, then 2, then stops on 3
;
; Error state 1 - debug port shows $81
;     => error during initloop - write/read test failed for some address
;
; Error state 2 - debug port shows $82
;     => error during testloop - readback failed for some address, likely that writes to other addresses corrupted it


entry:
	lda #0 : tax : tay              ; zero all registers

	inx : stx DEBUGPORT : tax       ; display 1 on the debug port

delayloop0:                         ; delay 256*(256*5-1 + 5) - 1 = 328703 cycles
	inx : bne delayloop0
	iny : bne delayloop0

initloop:
	tya : clc : adc #17 : sta 0,y   ; Calculate and store a unique value in each location, that's different to the actual address

	cmp 0,y : bne initloopfail      ; Check it was stored correctly	

	iny : bpl initloop              ; Advance to the next location and loop unless we've reached $80

	ldx #2 : stx DEBUGPORT          ; display 2 on the debug port

	ldx #0
delayloop1:                         ; delay 256*(256*5-1 + 5) - 1 = 328703 cycles
	inx : bne delayloop1
	iny : bne delayloop1

	ldy #$7f
testloop:
	tya : clc : adc #17             ; Recalculate the value for this memory location

	cmp 0,y : bne testloopfail      ; Check that the previously-stored value is still there and hasn't been overwritten

	dey : bpl testloop              ; Loop down through addresses

	lda #3 : sta DEBUGPORT          ; write 3 to debug port - test passed

stop:
	bra stop

initloopfail:
	lda #$81 : sta DEBUGPORT        ; write $81 to indicate failure during initloop
	bra stop

testloopfail:
	lda #$82 : sta DEBUGPORT        ; write $82 to indicate failure during testloop
	bra stop

irq:
	ldx #$ff : stx DEBUGPORT
	bra stop

