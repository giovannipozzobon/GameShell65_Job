.segment Zeropage "GameState Titles"
TextPosX:		.byte $00,$00
TextPosY:		.byte $00
TextPtr:		.word $0000
TextOffs:		.byte $00
TextEffect:		.byte $00

.segment Code "GameState Titles"

.macro TextSetPos(x,y) {
	lda #<x
	sta TextPosX+0
	lda #>x
	sta TextPosX+1
	lda #y
	sta TextPosY
}

.macro TextSetMsgPtr(message) {
    lda #<message
    sta TextPtr+0
    lda #>message
    sta TextPtr+1
}

.macro TextDrawSpriteMsg(center, sinoffs, applysin) {
	.if (applysin)
	{
	    clc
	    lda Irq.VBlankCount
	    adc #sinoffs
	    sta TextOffs
	    lda #$01
	    sta TextEffect
	}
	else
	{
		lda #$00
	    sta TextOffs
	    sta TextEffect
	}

	.if(center)
	{
		jsr SprCenterXPos
	}

    jsr SprPrintMsg
}

// ----------------------------------------------------------------------------
//

chrWide:
	.byte $10,$10,$10,$0f,$10,$0f,$0d,$10,$10,$07,$0c,$10,$0c,$11,$10,$11
	.byte $10,$11,$10,$10,$0f,$10,$10,$11,$0f,$10,$10,$10,$08,$10,$10,$10
	.byte $08,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
	.byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10

SprCenterXPos: {
	lda #$00
	sta TextPosX+0
	sta TextPosX+1

 	ldy #$00
oloop:
	lda (TextPtr),y
	cmp #$ff
	beq endtxt

	tax
 	lda chrWide,x
 	sta cwidth

 	clc
 	lda TextPosX+0
 	adc cwidth:#$00
 	sta TextPosX+0
 	lda TextPosX+1
 	adc #$00
 	sta TextPosX+1

 	iny
 	bra oloop

endtxt:
	// divide by 2
	lsr TextPosX+1
	ror TextPosX+0

	sec
	lda #<(SCREEN_WIDTH/2)
	sbc TextPosX+0
	sta TextPosX+0
	lda #>(SCREEN_WIDTH/2)
	sbc TextPosX+1
	sta TextPosX+1

	rts
}

SprPrintMsg: {
	lda #(0<<4) | $0f
	sta RRBSpr.Pal
	lda #$00
	sta RRBSpr.SChr
	lda #<sprFont.baseChar
	sta RRBSpr.BaseChr+0
	lda #>sprFont.baseChar
	sta RRBSpr.BaseChr+1

	lda TextPosX+0
	sta RRBSpr.XPos+0
	lda TextPosX+1
	sta RRBSpr.XPos+1

 	lda TextPosY
 	sta RRBSpr.YPos+0

 	ldy #$00

oloop:
	lda (TextPtr),y
	cmp #$ff
	beq endtxt

	// mult by 3 to get RRB sprite index
	sta mult3
	asl
	clc
	adc mult3:#$00
	sta RRBSpr.SChr

	lda TextEffect
	beq _noeffect

	clc
	tya
	adc TextOffs
	asl
	tax

	clc
	lda sintable2,x
	cmp #$80
	ror
	adc TextPosY
	sta RRBSpr.YPos+0
	bra _dodraw

_noeffect:
	lda TextPosY
	sta RRBSpr.YPos+0

_dodraw:
	lda #$01
 	jsr RRBSpr.Draw

 	lda mult3
 	tax
 	lda chrWide,x
 	sta letterWidth

	clc
	lda RRBSpr.XPos+0
	adc letterWidth:#$10
	sta RRBSpr.XPos+0
	lda RRBSpr.XPos+1
	adc #$00
	sta RRBSpr.XPos+1

	iny
	bra oloop

endtxt:

	rts
}

// ------------------------------------------------------------
//
// Titles State - show titles screen
//
gsIniTitles: {

	lda #$00
	sta Irq.VBlankCount

	lda #$00
	sta GameSubState
	sta GameStateTimer

	lda #$00
	sta GameStateData+0
	sta GameStateData+1
	sta GameStateData+2

	rts
}

// ------------------------------------------------------------
//
gsUpdTitles: {
	// Inc the game state timer
	_add16im(GameStateData, 1, GameStateData)
	lda GameStateData+0
	cmp #$c0
	lda GameStateData+1
	sbc #$02
	bcc !+
	_set16im(0, GameStateData)

	clc
	lda GameStateData+2
	adc #$01
	and #$03
	sta GameStateData+2
!:

// 	lda Player.DPadClick
// 	and #$10
// 	beq _not_fire

// 	lda #GStatePlay
// 	jsr SwitchGameStates

// _not_fire:

	rts
}

// ------------------------------------------------------------
//
gsDrwTitles: {

	TextSetPos($30,$38)
	TextSetMsgPtr(testTxt1)
	TextDrawSpriteMsg(true, 0, true)

	TextSetPos($30,$78)
	TextSetMsgPtr(testTxt2)
	TextDrawSpriteMsg(true, 64, true)

	lda #$b0
	sta TextPosY

	_add16im(Camera.XScroll, 1, Camera.XScroll)
	_add16im(Camera.YScroll, 1, Camera.YScroll)

	sec
	lda #<SCREEN_WIDTH
	sbc GameStateData+0
	sta TextPosX+0
	lda #>SCREEN_WIDTH
	sbc GameStateData+1
	sta TextPosX+1

	lda GameStateData+2
	asl
	tay

    lda introTxtTable,y
    sta TextPtr+0
    lda introTxtTable+1,y
    sta TextPtr+1

	TextDrawSpriteMsg(false, 0, true)

	rts
}

.segment Data "GameState Titles"

sintable2:
	.fill 256, (sin((i/256) * PI * 2) * 31)
costable2:
	.fill 256, (cos((i/256) * PI * 2) * 31)

introTxtTable:
	.word introTxt1, introTxt2, introTxt3, introTxt4

.encoding "screencode_mixed"
testTxt1:
	.text "game shell 65"
	.byte $ff
testTxt2:
	.text "[press fire to start]"
	.byte $ff

introTxt1:
	.text "welcome to gameshell65"
	.byte $ff
introTxt2:
	.text "code by retrocogs "
	.byte $1e
	.byte $ff
introTxt3:
	.text "iffl code by mirage "
	.byte $1f
	.byte $ff
introTxt4:
	.text "now go build your game "
	.byte $1f
	.byte $ff

