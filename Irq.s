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
    lda System.IRQBotPos+1
    beq _clear_bit
    lda #$80
    tsb $d011
    rts
_clear_bit:
    lda #$80
    trb $d011
	rts
}

irqHandler:
{
	php
	pha

	inc Irq.VBlankCount

	pla
	plp

	asl $d019
	rti
}

// ------------------------------------------------------------

}
