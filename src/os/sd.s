; SD card interface module
;
; This is adapted from https://github.com/gfoot/sdcard6502 to communicate 
; directly with a PLD-based hardware interface to the SD card, which 
; provides two MMIO addresses:
;
; SD_DATA   - writes initiate a send/receive operation (8 ticks of the clock)
;           - reads return the byte read from the card during the previous write
;
; SD_SETCS  - writes set or clear the SD card module's CS line based on D0
;
;
; Requires zero-page variable storage:
;   zp_sd_address - 2 bytes
;   zp_sd_currentsector - 4 bytes


sd_init:
.(
	; Let the SD card boot up, by pumping the clock with SD CS disabled

	; We need to apply around 80 clock pulses with CS and MOSI high.
	; Normally MOSI doesn't matter when CS is high, but the card is
	; not yet is SPI mode, and in this non-SPI state it does care.

	lda #0 : sta SD_SETCS    ; unassert CS
	
	dec        ; to $ff

	ldx #16    ; 10 plus a few extras
preinitloop:
	jsr sd_writebyte
	dex
	bne preinitloop


cmd0: ; GO_IDLE_STATE - resets card to idle state, and SPI mode
	lda #<sd_cmd0_bytes
	sta zp_sd_address
	lda #>sd_cmd0_bytes
	sta zp_sd_address+1

	jsr sd_sendcommand

	; Expect status response $01 (not initialized)
	cmp #$01
	bne initfailed

cmd8: ; SEND_IF_COND - tell the card how we want it to operate (3.3V, etc)
	lda #<sd_cmd8_bytes
	sta zp_sd_address
	lda #>sd_cmd8_bytes
	sta zp_sd_address+1

	jsr sd_sendcommand

	; Expect status response $01 (not initialized)
	cmp #$01
	bne initfailed

	; Read 32-bit return value, but ignore it
	jsr sd_readbyte
	jsr sd_readbyte
	jsr sd_readbyte
	jsr sd_readbyte

cmd55: ; APP_CMD - required prefix for ACMD commands
	lda #<sd_cmd55_bytes
	sta zp_sd_address
	lda #>sd_cmd55_bytes
	sta zp_sd_address+1

	jsr sd_sendcommand

	; Expect status response $01 (not initialized)
	cmp #$01
	bne initfailed

cmd41: ; APP_SEND_OP_COND - send operating conditions, initialize card
	lda #<sd_cmd41_bytes
	sta zp_sd_address
	lda #>sd_cmd41_bytes
	sta zp_sd_address+1

	jsr sd_sendcommand

	; Status response $00 means initialized
	cmp #$00
	bne notinitialized

	clc
	rts

notinitialized:
	; Otherwise expect status response $01 (not initialized)
	cmp #$01
	bne initfailed

	; Not initialized yet, so wait a while then try again.
	; This retry is important, to give the card time to initialize.

	ldx #0
	ldy #0
delayloop:
	dey
	bne delayloop
	dex
	bne delayloop

	jmp cmd55


initfailed:
.(
	jsr printimm
	.byte "SD init failed", 13, 10, 0
loop:
	bra loop
.)


sd_cmd0_bytes:
	.byte $40, $00, $00, $00, $00, $95
sd_cmd8_bytes:
	.byte $48, $00, $00, $01, $aa, $87
sd_cmd55_bytes:
	.byte $77, $00, $00, $00, $00, $01
sd_cmd41_bytes:
	.byte $69, $40, $00, $00, $00, $01

.)


sd_waitbyte:
.(
	; wait for busy flag low
	bit SD_STAT
	bmi sd_waitbyte
	rts
.)

sd_readbyte:
	jsr sd_waitbyte
	lda SD_DATA
	rts

sd_writebyte:
	jsr sd_waitbyte
	sta SD_DATA
	rts

sd_waitresult:
	; Wait for the SD card to return something other than $ff
	jsr sd_readbyte
	cmp #$ff
	beq sd_waitresult
	rts


sd_sendcommand:
	; Debug print which command is being executed

	;lda #'c'
	;jsr printchar
	;ldx #0
	;lda (zp_sd_address,x)
	;jsr printhex

	; Start command
	lda #1 : sta SD_SETCS

	ldy #0
	lda (zp_sd_address),y    ; command byte
	jsr sd_writebyte
	ldy #1
	lda (zp_sd_address),y    ; data 1
	jsr sd_writebyte
	ldy #2
	lda (zp_sd_address),y    ; data 2
	jsr sd_writebyte
	ldy #3
	lda (zp_sd_address),y    ; data 3
	jsr sd_writebyte
	ldy #4
	lda (zp_sd_address),y    ; data 4
	jsr sd_writebyte
	ldy #5
	lda (zp_sd_address),y    ; crc
	jsr sd_writebyte

	jsr sd_waitresult
	pha

	; Debug print the result code
	;jsr printhex

	; End command
	stz SD_SETCS

	pla   ; restore result code
	rts


sd_readsector:
.(
	; Read a sector from the SD card.  A sector is 512 bytes.
	;
	; Parameters:
	;    zp_sd_currentsector   32-bit sector number
	;    zp_sd_address     address of buffer to receive data
	
	lda #1 : sta SD_SETCS

	; Command 17, arg is sector number, crc not checked
	lda #$51                    ; CMD17 - READ_SINGLE_BLOCK
	jsr sd_writebyte
	lda zp_sd_currentsector+3   ; sector 24:31
	jsr sd_writebyte
	lda zp_sd_currentsector+2   ; sector 16:23
	jsr sd_writebyte
	lda zp_sd_currentsector+1   ; sector 8:15
	jsr sd_writebyte
	lda zp_sd_currentsector     ; sector 0:7
	jsr sd_writebyte
	lda #$01                    ; crc (not checked)
	jsr sd_writebyte

	jsr sd_waitresult
	cmp #$00
	bne fail

	; wait for data
	jsr sd_waitresult
	cmp #$fe
	bne fail

	; Need to read 512 bytes - two pages of 256 bytes each
	jsr readpage
	inc zp_sd_address+1
	jsr readpage
	dec zp_sd_address+1

	; End command
	stz SD_SETCS

	rts


fail:
	lda #'s'
	jsr printchar
	lda #':'
	jsr printchar
	lda #'f'
	jsr printchar
failloop:
	jmp failloop


readpage:
	; Read 256 bytes to the address at zp_sd_address
	ldy #0
readloop:
	jsr sd_readbyte
	sta (zp_sd_address),y
	iny
	bne readloop
	rts

.)

