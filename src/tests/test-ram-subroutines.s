; RAM test - subroutines
;
; Expected result - debug port shows 1 then counts quickly 2-5 many times, then stops on 6
;
; Error state 1 - debug port shows $81
;     => error in stackloop, pushing/popping data
;
; Error state 2 - debug port freezes on a number between 2 and 5
;     => error during subroutine test loop
;
; Error state 3 - debug port shows $ff
;     => BRK occured, likely error pushing/popping return addresses to the stack


entry:
	lda #0 : tax : tay              ; zero all registers

	inx : stx DEBUGPORT : tax       ; display 1 on the debug port

delayloop1:                         ; delay 256*(256*5-1 + 5) - 1 = 328703 cycles
	inx : bne delayloop1
	iny : bne delayloop1

	ldx #$7f : txs                  ; initialize the stack

	ldx #0
	bra stackloop

stackloopfailed:
	lda #$81 : sta DEBUGPORT
	bra stop

stackloop:                          ; test interacting with the stack
	stx $0
	txa : clc : adc #17 : sta $1
	
	pha : phx
	
	pla : cmp $0 : bne stackloopfailed
	pla : cmp $1 : bne stackloopfailed

	inx : bne stackloop


	stz $0                          ; loop counter

subroutineloop:
	ldx #2 : stx DEBUGPORT

	ldx #0
delayloop2:                         ; delay 256*(256*5-1 + 5) - 1 = 328703 cycles
	inx : bne delayloop2
	/*iny : bne delayloop2*/

	jsr subroutine1

	ldx #0
delayloop3:                         ; delay 256*(256*5-1 + 5) - 1 = 328703 cycles
	inx : bne delayloop3

	jsr subroutine2

	ldx #0
delayloop4:                         ; delay 256*(256*5-1 + 5) - 1 = 328703 cycles
	inx : bne delayloop4

	pha : pha : pla : pla

	ldx #5 : stx DEBUGPORT

	inc $0
	bne subroutineloop

	ldx #6 : stx DEBUGPORT

stop:
	bra stop

subroutine1:
	ldx #3 : stx DEBUGPORT
	rts

subroutine2:
	ldx #4 : stx DEBUGPORT
	rts

irq:
	ldx #$ff : stx DEBUGPORT
	bra stop

