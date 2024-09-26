.segment Zeropage "GameState Titles"
TextPosX:		.byte $00,$00
TextPosY:		.byte $00
TextPtr:		.word $0000
TextOffs:		.byte $00
TextEffect:		.byte $00

.segment Code "GameState Titles"

.macro TextSetPos(x,y) {
	lda #<x
	sta.zp TextPosX+0
	lda #>x
	sta.zp TextPosX+1
	lda #y
	sta.zp TextPosY
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

// ------------------------------------------------------------
//
.const NUM_OBJS1 = 256

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
	lda #$00
	sta DrawSChr

	lda #<sprFont.baseChar
	sta DrawBaseChr+0
	lda #>sprFont.baseChar
	sta DrawBaseChr+1

	lda TextPosX+0
	sta DrawPosX+0
	lda TextPosX+1
	sta DrawPosX+1

 	lda TextPosY
 	sta DrawPosY+0

 	ldy #$00

oloop:
	lda (TextPtr),y
	cmp #$ff
	beq endtxt

	// mult by 3 to get RRB sprite index
	sta mult2
	asl
	sta DrawSChr

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
	sta DrawPosY+0
	bra _dodraw

_noeffect:
	lda TextPosY
	sta DrawPosY+0

_dodraw:
 	jsr DrawPixie

 	lda mult2:#$00
 	tax
 	lda chrWide,x
 	sta letterWidth

	clc
	lda DrawPosX+0
	adc letterWidth:#$10
	sta DrawPosX+0
	lda DrawPosX+1
	adc #$00
	sta DrawPosX+1

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

	jsr InitObjData

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

	_add16im(Camera.XScroll, 1, Camera.XScroll)

	lda Irq.VBlankCount
	and #$00
	bne !+

	_add16im(Camera.YScroll, 1, Camera.YScroll)
	_and16im(Camera.YScroll, $ff, Camera.YScroll)

!:

	jsr UpdateObjData

	rts
}

// ------------------------------------------------------------
//
gsDrwTitles: {

	// Clear the work Pixie ram using DMA
	jsr ClearWorkPixies

	_set8im($0f, DrawPal)

	// _set16im(0, DrawPosX)
	// _set16im(16, DrawPosY)
	// _set16im(sprFont.baseChar, DrawBaseChr)
	// _set8im(2, DrawSChr)
	// jsr DrawPixie
	// rts

	jsr DrawObjData

	DbgBord(9)

	TextSetPos($30,$28)
	TextSetMsgPtr(testTxt1)
	TextDrawSpriteMsg(true, 0, true)

	TextSetPos($30,$68)
	TextSetMsgPtr(testTxt2)
	TextDrawSpriteMsg(true, 64, true)

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

// ------------------------------------------------------------
//
UpdateObjData:
{
	// Add Objs into the work ram here
	//
	ldx #$00
!:
	clc
	lda Objs1PosXLo,x
	adc Objs1VelXLo,x
	sta Objs1PosXLo,x
	lda Objs1PosXHi,x
	adc Objs1VelXHi,x
	and #$01
	sta Objs1PosXHi,x

	clc
	lda Objs1PosYLo,x
	adc Objs1VelY,x
	sta Objs1PosYLo,x

	inx
	cpx #NUM_OBJS1
	bne !-

	rts
}

// ------------------------------------------------------------
//
DrawObjData:
{
	lda #$00
	sta DrawPosY+1

	_set16im((sprFont.baseChar), DrawBaseChr)			// Start charIndx with first pixie char

	// Add Objs into the work ram here
	//
	ldx #$00
!:
	lda Objs1PosYLo,x
	sta DrawPosY+0

	sec
	lda Objs1PosXLo,x
	sbc #$20
	sta DrawPosX+0
	lda Objs1PosXHi,x
	sbc #$00
	sta DrawPosX+1

	lda Objs1Spr,x
	sta DrawSChr

	jsr DrawPixie

	inx
	cpx #NUM_OBJS1
	bne !-

	rts
}

// ------------------------------------------------------------
//
InitObjData:
{
    .var xpos = Tmp       // 16bit
    .var ypos = Tmp+2     // 8bit

	// Init Obj group 1
	//
	//
	_set16im(0, xpos)
	_set8im(0, ypos)

	ldx #$00
iloop1:
	lda xpos
	sta Objs1PosXLo,x
	lda xpos+1
	sta Objs1PosXHi,x
	lda ypos
	sta Objs1PosYLo,x
	lda #1
	sta Objs1VelY,x

	txa
	and #$01
	clc
	adc #$1e
	asl
	sta Objs1Spr,x

	txa
	and #$01
	bne ip1
	lda #$ff
	sta Objs1VelXLo,x
	sta Objs1VelXHi,x
	bra id1
ip1:
	lda #$01
	sta Objs1VelXLo,x
	lda #$00
	sta Objs1VelXHi,x
id1:

	_add16im(xpos, -14, xpos)
	_and16im(xpos, $1ff, xpos)
	_add8im(ypos, 5, ypos)

	inx
	cpx #NUM_OBJS1
	bne iloop1

	rts
}

// ---
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

// ------------------------------------------------------------
//
.segment BSS "Obj Data"

Objs1PosXLo:
	.fill NUM_OBJS1, 0
Objs1PosXHi:
	.fill NUM_OBJS1, 0
Objs1PosYLo:
	.fill NUM_OBJS1, 0
Objs1VelXLo:
	.fill NUM_OBJS1, 0
Objs1VelXHi:
	.fill NUM_OBJS1, 0
Objs1VelY:
	.fill NUM_OBJS1, 0
Objs1Spr:
	.fill NUM_OBJS1, 0



