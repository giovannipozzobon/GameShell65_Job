.namespace Irq
{

// ------------------------------------------------------------
//
.segment Zeropage "Irq zeropage"
Tmp7:			.word $0000

VBlankCount:	.byte $00
FadeComplete:	.byte $00
IRQPos:			.byte $00
IRQCount:		.byte $00

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

irqFadeOutHandler:
{
		php
		pha
		phx
		phy

		lda Irq.FadeComplete
		bne FadeoutCompleteIRQ

		lda Irq.Tmp7
		cmp #$03
		bne !+
		jsr DecreasePalette
		lda #$00
		sta Irq.Tmp7
!:		inc Irq.VBlankCount
		inc Irq.Tmp7
		lda Irq.VBlankCount
		cmp #60
		bne irqFadeOutHandlerEnd

FadeoutCompleteIRQ:
		lda #$01
		sta Irq.FadeComplete
		lda #$00								// code to run when fadeout is complete
		sta $d020
		sta $d020
		sta Irq.VBlankCount
		jsr System.DisableScreen

irqFadeOutHandlerEnd:
		ply
		plx
		pla
		plp

		asl $d019
		rti
}

DecreasePalette:
		ldx #$00

!DecreasePaletteLoop:
		lda $d100,x
		sec
		sbc #$01
		bcs !+
		lda #$00
!:		sta $d100,x

		lda $d200,x
		sec
		sbc #$01
		bcs !+
		lda #$00
!:		sta $d200,x

		lda $d300,x
		sec
		sbc #$01
		bcs !+
		lda #$00
!:		sta $d300,x

		inx
		bne !DecreasePaletteLoop-

		rts
		

IncreasePalette:
		lda #%00000010 //Edit=%00, Text = %00, Sprite = %01, Alt = %00
		sta $d070 

		clc
		lda #<(fadeTabStart+1)
fadeInVal:
		adc #$f0
		sta Irq.Tmp7+0
		lda #>(fadeTabStart+1)
		adc #$00
		sta Irq.Tmp7+1

        ldx #$00
!IncreasePaletteloop:
		.for(var p=0; p<14; p++) 
		{
			lda Palette + (p * $30) + $000,x
			tay
			lda swapNybbleTab,y
			tay
			lda (Irq.Tmp7),y
			sta $d100 + (p * $10),x

			lda Palette + (p * $30) + $010,x
			tay
			lda swapNybbleTab,y
			tay
			lda (Irq.Tmp7),y
			sta $d200 + (p * $10),x

			lda Palette + (p * $30) + $020,x
			tay
			lda swapNybbleTab,y
			tay
			lda (Irq.Tmp7),y
			sta $d300 + (p * $10),x
		}

		lda #$ff				// flash
		tay
		lda swapNybbleTab,y
		tay
		lda (Irq.Tmp7),y
		sta $d1f0,x
		sta $d2f0,x
		sta $d3f0,x

		inx
		cpx #$10
		lbne !IncreasePaletteloop-
		rts

fadeTabStart:
		.fill 256, 0
swapNybbleTab:
		.fill 256, (i>>4) | (i<<4)

irqHandler:
{
	pha
	phx
	phy

	dec Irq.IRQCount
	lbeq _lastIRQ

	// ldx Irq.IRQCount
	// lda rngtable,x
	// sta $d000

//	lda Irq.IRQPos
//	sta $d001

	lda Palette + $0e
	sta $d10e
	lda Palette + $1e
	sta $d20e
	lda Palette + $2e
	sta $d30e

	clc
	lda Irq.IRQPos
	adc #$02
	sta Irq.IRQPos
	sta $d012

	// clear the signal
	lsr $d019

	ply
	plx
	pla

	rti

_lastIRQ:	
	// This was the last IRQ, set the new IRQ at the bottom handler

    // change pointer to new interrupt
    lda #>irqBotHandler
    sta $ffff
    lda #<irqBotHandler
    sta $fffe

    // set the interrupt position
    jsr SetIRQBotPos

	// clear the signal
	lsr $d019

	ply
	plx
	pla

	rti
}

irqBotHandler:
{
	pha

	inc Irq.VBlankCount

	lda Irq.FadeComplete
	bne SkipFadeIn

	lda Irq.VBlankCount
	asl
	asl
	cmp #$00-4
	bcc !+
	lda #$01
	sta Irq.FadeComplete
	lda #$ff
!:	sta fadeInVal+1
	jsr IncreasePalette

SkipFadeIn:

	lda #$00
	sta $d021

    // change pointer to new interrupt
    lda #>irqHandler
    sta $ffff
    lda #<irqHandler
    sta $fffe

    lda #(NUM_ROWS*8)/2
    sta Irq.IRQCount

    // set the interrupt position
    lda System.IRQTopPos
    sta Irq.IRQPos
    sta $d012
    lda #$80
    trb $d011

	// clear the signal
	lsr $d019

	pla

	rti
}

// ------------------------------------------------------------

}
