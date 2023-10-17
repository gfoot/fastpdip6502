; Serial input and output test using buffers and serial IRQ rather than VIA

SERIAL_TDR = $ff60
SERIAL_STAT = $ff50 
SERIAL_RDR = $ff40


VIA_BASE = $ff20

VIA_PORTB = VIA_BASE+0
VIA_PORTA = VIA_BASE+1
VIA_DDRB = VIA_BASE+2
VIA_DDRA = VIA_BASE+3
VIA_T1CL = VIA_BASE+4
VIA_T1CH = VIA_BASE+5
VIA_T1LL = VIA_BASE+6
VIA_T1LH = VIA_BASE+7
VIA_T2CL = VIA_BASE+8
VIA_T2CH = VIA_BASE+9
VIA_SR = VIA_BASE+10
VIA_ACR = VIA_BASE+11
VIA_PCR = VIA_BASE+12
VIA_IFR = VIA_BASE+13
VIA_IER = VIA_BASE+14
VIA_PORTANH = VIA_BASE+15


zp_printptr = $80

zp_serial_out_head = $82
zp_serial_out_tail = $83
zp_serial_in_head = $84
zp_serial_in_tail = $85
zp_serial_error = $86

serial_out_buffer = $200
serial_in_buffer = $300


ramentry:

	; Disable all VIA interrupts, so we only need to deal with serial ones
	lda #$7f : sta VIA_IER

	; Initialize the output buffer
	stz zp_serial_out_head
	stz zp_serial_out_tail
	stz zp_serial_in_head
	stz zp_serial_in_tail
	stz zp_serial_error

	; Clear any pending serial interrupts
	bit SERIAL_STAT

	; Ensure we clear RDRF in case it was set
	bit SERIAL_RDR

	; In case TDRE got initialized unset, let's output one character directly,
	; without waiting for it, to ensure that it does get set now
	lda #10 : sta SERIAL_TDR

	; Enable interrupts now that we're ready
	cli


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


	; Wait for characters and echo them back
	lda #'>' : jsr printchar
loop:
	jsr getchar
	sta DEBUGPORT
	jsr printchar
	bra loop


message:
	.byte "Hello ", 0


getchar:
.(
	phy

	; Loop reading tail pointer until there's data to return
wait:
	ldy zp_serial_in_tail
	cpy zp_serial_in_head
	beq wait

	; Advance the pointer
	iny

	; Read the data
	lda serial_in_buffer,y

	; Store the pointer after reading the data - if we stored it 
	; first then it'd be possible for the IRQ handler to jump in
	; and overwrite our data
	sty zp_serial_in_tail

	ply : rts
.)


printchar:
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

	; Consider sending it straight away
	php : sei
	jsr serial_tick
	plp

	ply : rts
.)


printimm:
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

printmsg:
	stx zp_printptr
	sty zp_printptr+1

printmsgloop:
	lda (zp_printptr)
	beq endprintmsgloop
	jsr printchar
	inc zp_printptr
	bne printmsgloop
	inc zp_printptr+1
	bra printmsgloop

endprintmsgloop:
	rts


irq:
	; Check for pending serial operation
	jsr serial_tick

	rti


serial_tick:
.(
	; Read serial status register - also clears interrupt request
	bit SERIAL_STAT
	bvs receive_data	; RDRF - there's data to read
	bmi transmit_data	; TDRE - we can send data if we want to

	rts


receive_data:
.(
	phy

	; Load the head pointer to see if there's space to store the data
	ldy zp_serial_in_head
	iny
	cpy zp_serial_in_tail
	bne got_space_for_data

	; The buffer is full; we can't do much about this other than discard the new data
	bit SERIAL_RDR
	
	; Set a flag to say there was an error
	ldy #$ff : sty zp_serial_error

	bra receive_data_done

got_space_for_data:

	; Store the updated buffer pointer
	sty zp_serial_in_head

	; Read the character and store it
	pha
	lda SERIAL_RDR
	sta serial_in_buffer,y
	pla


receive_data_done:

	; Restore Y and branch back and check the status register again
	ply
	bra serial_tick
.)


transmit_data:
.(
	phy

	; Load the pointer and check there's data to send
	ldy zp_serial_out_tail
	cpy zp_serial_out_head
	beq transmit_buffer_empty	; no data to send

	; Increment the pointer
	iny
	sty zp_serial_out_tail

	; Transfer the data byte to the serial port
	pha
	lda serial_out_buffer,y
	sta SERIAL_TDR
	pla

transmit_buffer_empty:
	ply : rts
.)

.)

