; Loop test - simple loop to test ROM and debug port are working
;
; Expected result - debug port counts up, wrapping and looping forever


entry:
	cli
	lda #0 : tax : tay            ; zero all registers

initloop:
	clc : adc #1 : sta DEBUGPORT  ; increment A and report its value to the debug port

delayloop:
	inx : bne delayloop           ; delay 256*5 - 1 = 1279 cycles
	iny : bne delayloop           ; repeat the delay 256 times plus another 1279 cycles for the Y loop
                                  ; total delay = 256*1279 + 1279 = 328703 cycles

	bra initloop

irq:
	lda #$ff : sta DEBUGPORT
	bra irq

