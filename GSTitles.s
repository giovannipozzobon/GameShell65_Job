.segment Zeropage "GameState Titles"

.segment Code "GameState Titles"

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

	_set16im($0000, Camera.YScroll)
	_set16im($0001, Camera.CamVelY)

	_set16im($0000, Camera.XScroll)
	_set16im($0001, Camera.CamVelX)

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

//	_add16im(Camera.XScroll, 1, Camera.XScroll)

	lda Irq.VBlankCount
	and #$00
	lbne donemove

	_add16(Camera.XScroll, Camera.CamVelX, Camera.XScroll)
	_add16(Camera.YScroll, Camera.CamVelY, Camera.YScroll)

	// Min X bounds
	lda Camera.XScroll+1
	bpl !+

	_set16im($0000, Camera.XScroll)
	_set16im($0001, Camera.CamVelX)

!:

	// Max X bounds
	sec
	lda Camera.XScroll+0
	sbc #<MAXXBOUNDS
	lda Camera.XScroll+1
	sbc #>MAXXBOUNDS
	bmi !+

	_set16im(MAXXBOUNDS, Camera.XScroll)
	_set16im($ffff, Camera.CamVelX)

!:
	// Min Y bounds
	lda Camera.YScroll+1
	bpl !+

	_set16im($0000, Camera.YScroll)
	_set16im($0001, Camera.CamVelY)

!:

	// Max Y bounds
	sec
	lda Camera.YScroll+0
	sbc #<MAXYBOUNDS
	lda Camera.YScroll+1
	sbc #>MAXYBOUNDS
	bmi !+

	_set16im(MAXYBOUNDS, Camera.YScroll)
	_set16im($ffff, Camera.CamVelY)

!:

donemove:

	lda DPadClick
	and #$10
	beq _not_fire

	lda #GStatePlay
	jsr SwitchGameStates

_not_fire:

	rts
}

// ------------------------------------------------------------
//
gsDrwTitles: {

	_set8im($0f, DrawPal)

	// _set16im(0, DrawPosX)
	// _set16im(16, DrawPosY)
	// _set16im(sprFont.baseChar, DrawBaseChr)
	// _set8im(2, DrawSChr)
	// jsr DrawPixie
	// rts

	DbgBord(9)

	TextSetPos($30,$28)
	TextSetMsgPtr(testTxt1)
	TextDrawSpriteMsg(true, 0, true)

	DbgBord(10)

	TextSetPos($30,$68)
	TextSetMsgPtr(testTxt2)
	TextDrawSpriteMsg(true, 64, true)

	DbgBord(11)

	// lda System.TopBorder+0
	// lsr
	// lsr
	// lsr
	// lsr
	// and #$0f
	// tax
	// lda hexTable,x
	// sta testTxt3+0
	// lda System.TopBorder+0
	// and #$0f
	// tax
	// lda hexTable,x
	// sta testTxt3+1

	// TextSetPos($30,$08)
	// TextSetMsgPtr(testTxt3)
	// TextDrawSpriteMsg(true, 0, false)

	lda #$a0
	sta TextPosY


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

// ---
.segment Data "GameState Titles"

introTxtTable:
	.word introTxt1, introTxt2, introTxt3, introTxt4

.encoding "screencode_mixed"
testTxt1:
	.text "game shell 65"
	.byte $ff
testTxt2:
	.text "[press fire to start]"
	.byte $ff
testTxt3:
	.text "00"
	.byte $ff

hexTable:
	.text "0123456789abcdef"

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




