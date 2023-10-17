; RAM test - check we can write values to a specific RAM location
;
; Expected result - debug port shows 1, then incrementing values extremely quickly, then stops on 2
;
; Error state 1 - debug port slowly cycles between being blank, and showing two different values
;     => possible RAM write failure
;
; Error state 2 - debug port slowly cycles between being blank, and showing two different values, with the second value varying
;     => possible RAM read failure


entry:
	lda #0 : tax : tay              ; zero all registers

	inx : stx DEBUGPORT : tax       ; display 1 on the debug port

delayloop0:                         ; delay 256*(256*5-1 + 5) - 1 = 328703 cycles
	inx : bne delayloop0
	iny : bne delayloop0

initloop:
	clc : adc #1 : sta DEBUGPORT    ; increment A and report its value to the debug port

	beq initloopdone

	sta $0 : cmp $0 : beq initloop  ; store the value to address $0, check it's equal and loop if so

	; it wasn't equal, this is an error

errorloop:
	stz DEBUGPORT  ; blank the debug port

delayloop1:                         ; delay 256*(256*5-1 + 5) - 1 = 328703 cycles
	inx : bne delayloop1
	iny : bne delayloop1

	sta DEBUGPORT                   ; reshow the desired value

delayloop2:                         ; delay 256*(256*5-1 + 5) - 1 = 328703 cycles
	inx : bne delayloop2
	iny : bne delayloop2

	ldx $0 : stx DEBUGPORT          ; show the actual value read back

	ldx #0
delayloop3:                         ; delay 256*(256*5-1 + 5) - 1 = 328703 cycles
	inx : bne delayloop3
	iny : bne delayloop3

	bra errorloop

initloopdone:
	ldx #2 : stx DEBUGPORT

	ldx #0
delayloop4:                         ; delay 256*(256*5-1 + 5) - 1 = 328703 cycles
	inx : bne delayloop4
	iny : bne delayloop4

stop:
	bra stop

irq:
	ldx #$ff : stx DEBUGPORT
	bra stop

