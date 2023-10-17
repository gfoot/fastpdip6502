; 16-bit integer maths routines
;
; General interface is for X and maybe Y to be zero-page addresses of arguments to routines
;
; Much borrowing from the excellent VTL02 sources - https://github.com/Klaus2m5/VTL02/blob/master/vtl02sg.a65

.(

zp_scratch = $1e


;-----------------------------------------------------;
; 16-bit unsigned multiply routine: var[x] *= var[y]
; exit:    overflow is ignored/discarded, var[y] is result,
;          var[x] and scratch are modified, a = 0
;
&u16_mul:
.(
    lda  0,y
    sta  zp_scratch
    lda  1,y             ; {>} = var[y]
    sta  zp_scratch+1
    lda  #0
    sta  0,y             ; var[y] = 0
    sta  1,y
mul2:
    lda  zp_scratch
    ora  zp_scratch+1
    beq  mulrts          ; exit early if {>} = 0
    lsr  zp_scratch+1
    ror  zp_scratch      ; {>} /= 2
    bcc  mul3
    clc                  ; inline plus
    lda  0,y
    adc  0,x
    sta  0,y
    lda  1,y
    adc  1,x
    sta  1,y             ; end inline
mul3:
    asl  0,x
    rol  1,x             ; left-shift var[x]
    lda  0,x
    ora  1,x             ; loop until var[x] = 0
    bne  mul2
mulrts:
	rts
.)

; 16-bit signed multiply
&s16_mul:
.(
	pha

	stz zp_scratch   ; result sign in low bit
	
.(
	bit 1,x
	bpl next

	jsr s16_neg

	inc zp_scratch   ; toggle sign bit
next:
.)

.(
	lda 1,y
	bpl next

	jsr s16_negy
	
	inc zp_scratch   ; toggle sign bit
next:
.)

	lda zp_scratch : and #1 : pha

	jsr u16_mul

	pla : beq done

	jsr s16_negy

done:
	pla
	rts
.)


&s16_abs:
	bit 1,x
	bpl return

&s16_neg:
	pha
	sec
	lda #0 : sbc 0,x : sta 0,x
	lda #0 : sbc 1,x : sta 1,x
	pla
return:
	rts


&s16_negy:
	pha
	sec
	lda #0 : sbc 0,y : sta 0,y
	lda #0 : sbc 1,y : sta 1,y
	pla
	rts




&s16_div64:
.(
	lda 1,x
	sta zp_scratch
	lsr : ror 0,x
	lsr : ror 0,x
	lsr : ror 0,x
	lsr : ror 0,x
	lsr : ror 0,x
	lsr : ror 0,x

	; If it was negative we're missing some high bits that should be set
	bit zp_scratch : bpl pos
	ora #$fc
pos:

	sta 1,x
	rts
.)


.)

