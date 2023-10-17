; VIA data transfer test

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


entry:
	ldx #$ff : txs
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

* = $0
ramcodebase:

ramentry:

	lda #$00 : sta VIA_DDRB
	lda #$08 : sta VIA_PCR
	lda #$02 : sta VIA_IFR
	lda #$82 : sta VIA_IER
	
startwait:
	bit VIA_PORTB
	bpl startwait

	; Send a byte to start
	ldx #$ff : stx VIA_DDRA
	ldx #0 : stx VIA_PORTA
	stx DEBUGPORT

	; Wait for receiver to consume the byte
	jsr waitca1

	; Send another
	inx : stx VIA_PORTA
	stx DEBUGPORT
	jsr waitca1

	inx : stx DEBUGPORT

	; Peripheral consumed both bytes - switch to receive mode
	ldx #0 : stx VIA_DDRA
	bit VIA_PORTA ; send a handshake to confirm we're ready to receive

	; Wait for a byte, read it and display it
	jsr waitca1
	ldx VIA_PORTA : stx DEBUGPORT

	; And another one
	jsr waitca1
	ldx VIA_PORTA : stx DEBUGPORT

	; Now we switch back into write mode - wait for another handshake from the peripheral
	; to tell us it's switched to read mode
	jsr waitca1

	; Then switch to write mode and send a final byte
	ldx #$ff : stx VIA_DDRA
	ldx #$2a : stx VIA_PORTA
	jsr waitca1

stop:
	bra stop

	; Wait for peripheral
waitca1:
	lda #2   ; CA1's bit
waitca1loop:
	bit VIA_IFR
	beq waitca1loop
	rts


ramcodeend:

payloadsize = ramcodeend-ramcodebase
#print payloadsize

* = payload + payloadsize

