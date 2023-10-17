; RAM test program using only debug port for output

DEBUGPORT = $ff70

* = $ROMBASE
	.dsb $fe00-*, 0

entry:
	ldx #$ff : txs
	sei : clv : cld : cpx #0
	inx : txa : tay

; RAM test - check we can write and read back all RAM locations independently
;
; Expected result - debug port shows 1, 2, 3, 4, and stops on 5
;
; Error state 1 - debug port shows $81
;     => error during initloop - write/read test failed for some address
;
; Error state 2 - debug port shows $82
;     => error during testloop - readback failed for some address, likely that writes to other addresses corrupted it

	inx : stx DEBUGPORT : tax       ; display 1 on the debug port

delayloop0:                         ; delay 256*(256*5-1 + 5) - 1 = 328703 cycles
	inx : bne delayloop0
	iny : bne delayloop0

initloop:
	tya : clc : adc #17 : sta 0,y   ; Calculate and store a unique value in each location, that's different to the actual address

	cmp 0,y : bne initloopfail      ; Check it was stored correctly	

	iny : bne initloop              ; Advance to the next location and loop unless we've reached 0 again

	ldx #2 : stx DEBUGPORT          ; display 2 on the debug port

	ldx #0
delayloop1:                         ; delay 256*(256*5-1 + 5) - 1 = 328703 cycles
	inx : bne delayloop1
	iny : bne delayloop1

testloop:
	tya : clc : adc #17             ; Recalculate the value for this memory location

	cmp 0,y : bne testloopfail      ; Check that the previously-stored value is still there and hasn't been overwritten

	dey : bne testloop              ; Loop down through addresses

	lda #3 : sta DEBUGPORT          ; write 3 to debug port - zero page test passed

	bra allmem


stop:
	bra stop

initloopfail:
	lda #$09 : sta DEBUGPORT        ; write $09 to indicate failure during initloop
	bra stop

testloopfail:
	lda #$0a : sta DEBUGPORT        ; write $0a to indicate failure during testloop
	bra stop

allmeminitloopfail:
	lda 1 : and #$f0 : ora #$b
	sta DEBUGPORT                   ; write $xb to indicate failure during allmeminitloop
	bra stop

allmemtestloopfail:
	lda 1 : and #$f0 : ora #$c
	sta DEBUGPORT                   ; write $xc to indicate failure during allmemtestloop
	bra stop


allmem:
	iny : sty 1 : dey : sty 0       ; Now we use a pointer in zero page to access all the rest of the RAM
	
allmeminitloop:
	tya : clc : adc 1 : sta (0),y   ; Calculate and store a unique value in each location, that's different to the actual address

	cmp (0),y : bne allmeminitloopfail ; Check it was stored correctly	

	iny : bne allmeminitloop        ; Advance to the next location and loop unless we've reached $00

	inc 1
	lda 1 : and #$f0 : ora #3 : sta DEBUGPORT
	lda 1
	cmp #$fe : bne allmeminitloop   ; Advance to the next page, and loop unless we've reached $fe

	ldx #4 : stx DEBUGPORT          ; display 4 on the debug port

	ldx #0
delayloop2:                         ; delay 256*(256*5-1 + 5) - 1 = 328703 cycles
	inx : bne delayloop2
	iny : bne delayloop2

	ldy #1 : sty 1 : dey : sty 0    ; Reset the pointer
	
allmemtestloop:
	tya : clc : adc 1               ; Recalculate the value for this memory location

	cmp (0),y : bne allmemtestloopfail ; Check that the previously-stored value is still there and hasn't been overwritten

	dey : bne allmemtestloop        ; Loop down through addresses

	inc 1
	lda 1 : and #$f0 : ora #4 : sta DEBUGPORT
	lda 1
	cmp #$fe : bne allmemtestloop   ; Advance to next page, loop until $fe

	lda #5 : sta DEBUGPORT          ; write 5 to debug port - full RAM test passed

	ldx #0
delayloop3:                         ; delay 256*(256*5-1 + 5) - 1 = 328703 cycles
	inx : bne delayloop3
	iny : bne delayloop3

	jmp entry


top:
	.dsb $ff00-*, $00
#print top-entry
#print *-top

ioports:
	.dsb $c0, $00

ffc0:
irq:
	ldx #$ff : stx DEBUGPORT
	bra irq

nmi:
	ldx #$fe : stx DEBUGPORT
	bra nmi
	

toptop:
	.dsb $fffa-*, $00

#print *-toptop

vectors:
	.word nmi
	.word entry
	.word irq

