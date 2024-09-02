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

