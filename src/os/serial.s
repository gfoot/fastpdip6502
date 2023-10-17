; OS serial I/O module
;
; For custom serial interface
;
; SER_RDR  - reads read a byte from the interface and clear the RDRF flag
;
; SER_TDR  - writes write a byte to the interface and clear the TDRE flag
;
; SER_STAT - reads return flags:
;                bit 7 = TDRE (transmit data register empty - can transmit)
;                bit 6 = RDRF (receive data register full - can read)
;                bit 5 = RXOF (receive overflow - data lost)
;                bit 4 = FERR (framing error - data lost)
;
;            writes clear the IRQ state and reset RXOF and FERR without 
;            affecting TDRE or RDRF

.(

&serialout_init:
.(
	; Initialise the buffer system
	stz zp_serial_out_head
	stz zp_serial_out_tail
	stz zp_serial_in_head
	stz zp_serial_in_tail
	stz zp_serial_error

	; Print some characters
	lda #65 : jsr printchar
	lda #90 : jsr printchar
	lda #13 : jsr printchar
	lda #10 : jsr printchar

	; Print a whole message
	ldx #<message
	ldy #>message
	jsr printmsg

	; Print a message inlined in the code
	jsr printimm
	.byte "world!", 13, 10, 0

	rts

message:
	.byte "Hello ", 0
.)




; Serial housekeeping - often called from an interrupt handler, but not always.
; Polling the serial status clears any pending interrupt, so it's important that if 
; we do this, we handle all the possible interrupt causes, so that handling is
; consolidated here.
;
; We clobber A so caller must save it.
&serialout_tick:
.(
	; Process reads first as they are more time-critical

	asl : bpl checkwrites       ; bit 6 (RDRF) => bit 7

.(
	php

	lda SER_RDR
	sta DEBUGPORT

	phy

	ldy zp_serial_in_head : iny
	cpy zp_serial_in_tail : beq serialin_full
	sty zp_serial_in_head

	sta serial_in_buffer,Y
	
	ply
	plp
	bra checkwrites

serialin_full:
	lda #$f6 : sta DEBUGPORT
	lda #$ff : sta zp_serial_error
	ply : plp
.)

checkwrites:
	bcc return                 ; old bit 7 (TDRE) is now in carry

	; Transfer data register empty, so send the next byte if any
.(
	phy

	; Load the pointer and check there's data to send
	ldy zp_serial_out_tail
	cpy zp_serial_out_head
	beq skip                 ; no data to send

	; Increment the pointer
	iny
	sty zp_serial_out_tail

	; Transfer the data byte to the serial port
	lda serial_out_buffer,y
	sta SER_TDR

skip:
	ply
.)

return:
	rts
.)


&printchar:
.(
	phy

	; Load and advance the head pointer
	ldy zp_serial_out_head
	iny

	; Wait for space in the buffer
wait:
	cpy zp_serial_out_tail
	beq wait

	; Write the byte to the buffer and update the head pointer
	sta serial_out_buffer,y
	sty zp_serial_out_head
	
	ply

	; Consider sending it straight away

	pha : php : sei

	lda SER_STAT
	jsr serialout_tick

	plp : pla

	rts
.)


&printimm:
	pha : phx

	tsx
	clc
	lda $103,x : adc #1 : sta zp_printptr
	lda $104,x : adc #0 : sta zp_printptr+1

	jsr printmsgloop

	lda zp_printptr : sta $103,x
	lda zp_printptr+1 : sta $104,x

	plx : pla
	rts

&printmsg:
	stx zp_printptr
	sty zp_printptr+1

printmsgloop:
.(
	lda (zp_printptr)
	beq end
	jsr printchar
	inc zp_printptr
	bne printmsgloop
	inc zp_printptr+1
	bra printmsgloop

end:
	rts
.)


&printhex:
	pha
	ror : ror : ror : ror
	jsr print_nybble
	pla
print_nybble:
.(
	pha
	and #15
	cmp #10
	bmi skipletter
	adc #6
skipletter:
	adc #48
	jsr printchar
	pla
	rts
.)


&printnewline:
	lda #10 : jsr printchar
	lda #13 : jmp printchar


&serial_getchar:
.(
	phy
	
	bit zp_serial_error      ; set overflow flag to bit 6

	ldy zp_serial_in_tail

nodata:
	cpy zp_serial_in_head : beq nodata

	iny : sty zp_serial_in_tail

	lda serial_in_buffer,Y

	ply
	rts
.)


.)

