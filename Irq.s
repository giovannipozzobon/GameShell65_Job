.namespace Irq
{

// ------------------------------------------------------------
//
.segment Zeropage "Irq zeropage"
VBlankCount:	.byte $00
IRQPos:			.byte $00

// ------------------------------------------------------------
//
.segment Code "Irq code"

SetIRQBotPos: {
    // set the interrupt position
    lda System.IRQBotPos+0
    sta $d012
	lda $d011
	and #$7f
	sta msb

	lda System.IRQBotPos+1
    beq _set_msb

	lda msb
	ora #$80
	sta msb

_set_msb:
	lda msb:#$00
	sta $d011

	rts
}

irqHandler:
{
	php
	pha

	inc Irq.VBlankCount

	jsr SetIRQBotPos

	asl $d019

	pla
	plp

	rti
}

// ------------------------------------------------------------

}
