; OS entrypoint after copying to RAM

&osentry:
	ldx #$ff : txs
	jmp osinit

