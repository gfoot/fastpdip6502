; OS initialization

.(
&osinit:
	jsr irq_init
	jsr serialout_init
	jsr sd_init
	jsr fat32_init
	bcc fat32initok

	jsr printimm
	.byte "FAT32 init failed at stage ", 0
	lda fat32_errorstage : jsr printhex
	jsr printnewline
stop:
	bra stop

fat32initok:

.(
outerloop:
	lda #'>' : jsr printchar

	ldx #0
loop:
	jsr serial_getchar
	bvs error
	cmp #10 : beq linedone
	cmp #127 : beq delete

	cpx #$ff : beq loop
	sta buffer,x
	inx
	jsr printchar
	jmp loop

error:
	lda #$f4 : sta DEBUGPORT
	jsr printimm
	.byte 13, 10, 10, "Serial read error", 13, 10, 0
	jmp outerloop

delete:
	cpx #0 : beq loop
	dex
	jsr printimm
	.byte 8,32,8,0
	jmp loop

linedone:
	lda #0 : sta buffer,x

	jsr printimm
	.byte 13,10,10,0

	cpx #0 : beq outerloop
	
	lda #'"' : jsr printchar

	ldx #<buffer
	ldy #>buffer
	jsr printmsg

	jsr printimm
	.byte '"',13,10,10,0

	jsr sdtest
	jmp outerloop
.)


sdtest:
.(
  jsr printimm
  .byte "open root", 13, 10, 0

  ; Open root directory
  jsr fat32_openroot

  jsr printimm
  .byte "find subdir", 13, 10, 0

  ; Find subdirectory by name
  ldx #<subdirname
  ldy #>subdirname
  jsr fat32_finddirent
  bcc foundsubdir

  ; Subdirectory not found
  lda #'X'
  jsr printchar
  jmp loop

foundsubdir:

  jsr printimm
  .byte "open subdir", 13, 10, 0

  ; Open subdirectory
  jsr fat32_opendirent

  jsr printimm
  .byte "find file", 13, 10, 0

  ; Find file by name
  ldx #<filename
  ldy #>filename
  jsr fat32_finddirent
  bcc foundfile

  ; File not found
  lda #'Y'
  jsr printchar
  jmp loop

foundfile:
 
  jsr printimm
  .byte "open file", 13, 10, 0

  ; Open file
  jsr fat32_opendirent

  jsr printimm
  .byte "read file", 13, 10, 0

  ; Read file contents into buffer
  lda #<buffer
  sta fat32_address
  lda #>buffer
  sta fat32_address+1

  jsr fat32_file_read


  jsr hexdumpbuffer


  ldy #<buffer : sty 0
  ldy #>buffer : sty 1
  ldy #0
  ldx #2
printloop:
  lda (0),y
  jsr printchar

  iny
  bne printloop

  inc 1
  dex
  bne printloop

  jsr printnewline
  jsr printnewline
  rts

  ; loop forever
loop:
  jmp loop


subdirname:
  .byte "SUBFOLDR   ", 0
filename:
  .byte "DEEPFILETXT", 0

.)


hexdumpbuffer:
.(
	lda #<buffer : sta 0
	lda #>buffer : sta 1
	lda #32 : sta 2
	ldx #16
	ldy #0
dumploop:
	lda (0),y : jsr printhex
	lda #' ' : jsr printchar
	iny
	bne ynot0
	inc 1
ynot0:
	dex
	bne dumploop
	jsr printnewline
	ldx #16
	dec 2
	bne dumploop

	jsr printnewline
	jsr printnewline

	rts
.)


buffer:
	.dsb 512,0
.)

