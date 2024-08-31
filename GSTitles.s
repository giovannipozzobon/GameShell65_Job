.segment Code "GameState Titles"

// ------------------------------------------------------------
//
// Titles State - show titles screen
//
gsIniTitles: {

	jsr InitFadeIn

	jsr LayerDClear
	jsr DrawLogo

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

	ldx VBlankCount
	clc
	lda costable2,x
	adc #$28
	ldx #LayerD.id
	jsr Layers.SetXPosLo
	lda #$00
	jsr Layers.SetXPosHi

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

	TextSetPos($30,$78)
	TextSetMsgPtr(testTxt2)
	TextDrawSpriteMsg(true, 64, true)

	lda #$00
	sta $d020

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

//
DrawLogo: {
	.var chr_ptr = Tmp					// 16bit
	.var attrib_ptr = Tmp+2				// 16bit
	.var o_chr_offs = Tmp1				// 16bit
	.var chr_offs = Tmp1+2				// 16bit

	_set16im((logoChars.addr/64), o_chr_offs)

	_set16im(LayerDTileBuffer + 4 + (5 * LayerD.ChrSize), chr_ptr)
	_set16im(LayerDAttribBuffer + 4 + (5 * LayerD.ChrSize), attrib_ptr)

	ldz #$00
!rloop:

		_add16im(o_chr_offs, 0, chr_offs)

		ldy #$00

		ldx #$00
	!cloop:
		lda chr_offs+0
		sta (chr_ptr),y
		lda #$08
		sta (attrib_ptr),y
		iny
		lda chr_offs+1
		sta (chr_ptr),y
		lda #$0f
		sta (attrib_ptr),y
		iny

		inw chr_offs

		inx
		cpx #14
		bne !cloop-

	_add16im(o_chr_offs, 14, o_chr_offs)

	_add16im(chr_ptr, LayerD.ChrSize, chr_ptr)
	_add16im(attrib_ptr, LayerD.ChrSize, attrib_ptr)

	inz
	cpz #6
	bne !rloop-

	rts
}


.segment Data "GameState Titles"

introTxtTable:
	.word introTxt1, introTxt2, introTxt3, introTxt4

.encoding "screencode_mixed"
introTxt1:
	.text "welcome to firstshot"
	.byte $ff
introTxt2:
	.text "code by retrocogs "
	.byte $1e
	.byte $ff
introTxt3:
	.text "gfx and code by mirage "
	.byte $1f
	.byte $ff
introTxt4:
	.text "music by crisps "
	.byte $1f
	.byte $ff

