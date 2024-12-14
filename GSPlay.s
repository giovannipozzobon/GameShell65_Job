// ------------------------------------------------------------
//
.const NUM_OBJS1 = 256

.segment Zeropage "GameState Play"

.segment Code "GameState Play"

// ------------------------------------------------------------
//
// Titles State - show titles screen
//
gsIniPlay: {

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

	jsr InitObjData

	rts
}

// ------------------------------------------------------------
//
gsUpdPlay: {
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

	jsr UpdateObjData

	lda DPadClick
	and #$10
	beq _not_fire

	lda #GStateTitles
	jsr SwitchGameStates

_not_fire:

	rts
}

// ------------------------------------------------------------
//
gsDrwPlay: {

	_set8im($0f, DrawPal)

	// _set16im(0, DrawPosX)
	// _set16im(16, DrawPosY)
	// _set16im(sprFont.baseChar, DrawBaseChr)
	// _set8im(2, DrawSChr)
	// jsr DrawPixie
	// rts

	jsr DrawObjData

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
.segment Data "GameState Play"

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



