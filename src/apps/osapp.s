* = $700

	lda #$4c : sta $200
	lda #<irq : sta $201
	lda #>irq : sta $202

#include "os/oscode.s"

