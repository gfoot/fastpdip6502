.(

zp_scratch = $18


&printhex:
	pha
	ror : ror : ror : ror
	jsr printnybble
	pla
&printnybble:
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


&printhex16:
	pha
	lda 1,x : jsr printhex
	lda 0,x : jsr printhex
	pla
	rts

&printhex24:
	pha
	lda 2,x : jsr printhex
	lda 1,x : jsr printhex
	lda 0,x : jsr printhex
	pla
	rts

&printhex32:
	pha
	lda 3,x : jsr printhex
	lda 2,x : jsr printhex
	lda 1,x : jsr printhex
	lda 0,x : jsr printhex
	pla
	rts


&printspace:
	lda #' '
	jmp printchar


&printnewline:
	jsr printimm
	.byte 13,10,0
	rts


&printdecs16:
	; Print 16-bit signed number in decimal - X = address of 16-bit value in page zero
	bit 1,x
	bpl printdecu16

	pha
	lda #'-' : jsr printchar

	sec
	lda #0 : sbc 0,x : sta zp_scratch
	lda #0 : sbc 1,x : sta zp_scratch+1

	bra printdecu16_fromscratch_pla


	; Print 16-bit unsigned number in decimal - X = address of 16-bit value in page zero
	;
	; Adapted from http://forum.6502.org/viewtopic.php?f=2&t=4894#p55800
&printdecu16:

	pha

	lda 0,x : sta zp_scratch
	lda 1,x : sta zp_scratch+1

printdecu16_fromscratch_pla:
.(
	phy
    lda  #0           ; null delimiter for print
    pha   
prnum2:               ;   divide var[x] by 10
    lda  #0
    sta  zp_scratch+2 ; clr BCD
    ldy  #16
prdiv1:
    asl  zp_scratch   ; var[x] is gradually replaced
    rol  zp_scratch+1 ;   with the quotient
    rol  zp_scratch+2 ; BCD result is gradually replaced
    lda  zp_scratch+2 ;   with the remainder
    sec
    sbc  #10          ; partial BCD >= 10 ?
    bcc  prdiv2
    sta  zp_scratch+2 ;   yes: update the partial result
    inc  zp_scratch   ;   set low bit in partial quotient
prdiv2:
    dey
    bne  prdiv1       ; loop 16 times
    lda  zp_scratch+2
    ora  #'0'         ;   convert BCD result to ASCII
    pha               ;   stack digits in ascending
    lda  zp_scratch   ;     order ('0' for zero)
    ora  zp_scratch+1
    bne  prnum2       ; } until var[x] is 0
    pla
prnum3:
    jsr  printchar    ; print digits in descending
    pla               ;   order until delimiter is
    bne  prnum3       ;   encountered

	ply : pla
	rts
.)

	; Print 24-bit unsigned number in decimal - X = address of 24-bit value in page zero
	;
	; Adapted from http://forum.6502.org/viewtopic.php?f=2&t=4894#p55800
&printdecu24:

	pha

	lda 0,x : sta zp_scratch
	lda 1,x : sta zp_scratch+1
	lda 2,x : sta zp_scratch+2

printdecu24_fromscratch_pla:
.(
	phy
    lda  #0           ; null delimiter for print
    pha   
prnum2:               ;   divide var[x] by 10
    lda  #0
    sta  zp_scratch+3 ; clr BCD
    ldy  #24
prdiv1:
    asl  zp_scratch   ; var[x] is gradually replaced
    rol  zp_scratch+1 ;   with the quotient
    rol  zp_scratch+2 ;   ...
    rol  zp_scratch+3 ; BCD result is gradually replaced
    lda  zp_scratch+3 ;   with the remainder
    sec
    sbc  #10          ; partial BCD >= 10 ?
    bcc  prdiv2
    sta  zp_scratch+3 ;   yes: update the partial result
    inc  zp_scratch   ;   set low bit in partial quotient
prdiv2:
    dey
    bne  prdiv1       ; loop 24 times
    lda  zp_scratch+3
    ora  #'0'         ;   convert BCD result to ASCII
    pha               ;   stack digits in ascending
    lda  zp_scratch   ;     order ('0' for zero)
    ora  zp_scratch+1
    ora  zp_scratch+2
    bne  prnum2       ; } until var[x] is 0
    pla
prnum3:
    jsr  printchar    ; print digits in descending
    pla               ;   order until delimiter is
    bne  prnum3       ;   encountered

	ply : pla
	rts
.)


.)

