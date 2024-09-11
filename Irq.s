.namespace Irq
{

// ------------------------------------------------------------
//
.segment Zeropage "Irq zeropage"
VBlankCount:	.byte $00
IRQPos:			.byte $00
Tmp:			.byte $00

// ------------------------------------------------------------
//
.segment Code "Irq code"

SetIRQTopPos: {
	// 
    // set the interrupt position
    lda System.IRQTopPos+0
    sta $d012
    lda System.IRQTopPos+1
    beq _clear_bit
    lda #$80
    tsb $d011
    rts
_clear_bit:
    lda #$80
    trb $d011
	rts
}

SetIRQBotPos: {
	// 
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

irqTopHandler:
{
	php
	pha
    phx

	DbgBord(4)

    ldx #$00
!:
    lda #$00
    lda #$01

	jsr SetIRQBotPos

    inx
    bne !-


    lda #<Irq.irqBotHandler
    sta $fffe
    lda #>Irq.irqBotHandler
    sta $ffff

	asl $d019

	DbgBord(0)

    plx
	pla
	plp

	rti
}

irqBotHandler:
{
	php
	pha

	inc Irq.VBlankCount

	jsr SetIRQTopPos

    lda #<Irq.irqTopHandler
    sta $fffe
    lda #>Irq.irqTopHandler
    sta $ffff

	asl $d019

	pla
	plp

	rti
}

// ------------------------------------------------------------

}
