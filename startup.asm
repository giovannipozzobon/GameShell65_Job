.file [name="startup.prg", type="bin", segments="Code,Data"]

#define USE_DBG

// ------------------------------------------------------------
// Memory layout
//
.const COLOR_RAM = $ff80a00		// + 26*40*2

.const SCREEN_RAM = $50000		// Upto $4000 in size

.const CHARS_RAM = $20000		// Upto $c000 in size

// ------------------------------------------------------------
// Defines to describe the screen size
//
// If you use H320 then SCREEN_WIDTH much be <= 360, otherwise <= 720
#define H320
.const SCREEN_WIDTH = 336

// If you use V200 then SCREEN_HEIGHT much be <= 240, otherwise <= 480
#define V200
.const SCREEN_HEIGHT = 208

.const TILES_WIDE = (SCREEN_WIDTH/16)+1

// ------------------------------------------------------------
//
.segmentdef Zeropage [start=$02, min=$02, max=$fb, virtual]
.segmentdef Code [start=$2000, max=$7fff]
.segmentdef Mapped8000 [start=$8000, max=$9fff, virtual]
.segmentdef Data [start=$a000, max=$cfff]
.segmentdef BSS [start=$e000, max=$f400, virtual]

.segmentdef ScreenRam [start=SCREEN_RAM, virtual]
.segmentdef RRBWorkRam [startAfter="ScreenRam", max=SCREEN_RAM+$ffff, virtual]
.segmentdef MapRam [startAfter="RRBWorkRam", max=SCREEN_RAM+$ffff, virtual]

.cpu _45gs02				

#import "includes/m65macros.s"

#import "includes/layers_Functions.s"
#import "includes/assets_Functions.s"

// ------------------------------------------------------------
//
.const Layer1 = Layer_BG("stars", TILES_WIDE, true, 1)
.const LayerRRB = Layer_RRB("rrb", 127, 1)				// This is capped at 127 max due to index register limitation
.const LayerD = Layer_BG("dbg", 42, false, 0)
.const LayerEOL = Layer_EOL("eol")

// ------------------------------------------------------------
//

.const NUM_ROWS = 26

.const BGROWSIZE = 32 * 2

// ------------------------------------------------------------
//
.enum {
	PAL_FONTHUD,
	PAL_BG0
}

// ------------------------------------------------------------
//
.segment Zeropage "Main zeropage"

Tmp:			.word $0000,$0000		// General reusable data
Tmp1:			.word $0000,$0000
Tmp2:			.word $0000,$0000
Tmp3:			.word $0000,$0000
Tmp4:			.word $0000,$0000
Tmp5:			.word $0000,$0000
Tmp6:			.word $0000,$0000
Tmp7:			.word $0000

VBlankCount:	.byte $00
FadeComplete:	.byte $00
IRQPos:			.byte $00
IRQCount:		.byte $00

GameState:		.byte $00		// Titles / Play / HiScore etc
GameSubState:	.byte $00
GameStateTimer:	.byte $00
GameStateData:	.byte $00,$00,$00

TileYPos:		.byte $00

TextPosX:		.byte $00,$00
TextPosY:		.byte $00
TextPtr:		.word $0000
TextOffs:		.byte $00
TextEffect:		.byte $00

.macro TextSetPos(x,y) {
	lda #<x
	sta TextPosX+0
	lda #>x
	sta TextPosX+1
	lda #y
	sta TextPosY
}

.macro TextPrintMsg(message) {
    lda #<message
    sta TextPtr+0
    lda #>message
    sta TextPtr+1
    jsr LayerDPrintMsg
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
	    lda VBlankCount
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

//--------------------------------------------------------
// Main
//--------------------------------------------------------
.segment Code

* = $2000
	jmp Entry

.print "--------"

.const bgCharsBegin = SetAssetAddr(CHARS_RAM, $30000)
.const bg0Chars = AddAsset("FS-C0", "sdtest2/bg20_chr.bin")
.const logoChars = AddAsset("FS-LOGO", "sdcard/logo_alt_chr.bin")
.const hudChars = AddAsset("FS-HUD", "sdcard/hud_chr.bin")
.const hudShieldBarChars = AddAsset("FS-HUDSB", "sdcard/hudShieldBar_chr.bin")
.const sprFont = AddAsset("FS-F0", "sdcard/font_chr.bin")
.const sprEnemy = AddAsset("FS-SE0", "sdcard/enemy_chr.bin")
.const sprEnemyBlob = AddAsset("FS-SE1", "sdcard/enemyblob_chr.bin")
.const sprEnemySpark = AddAsset("FS-SE2", "sdcard/enemyspark_chr.bin")
.const sprEnemyInfectedSwarm = AddAsset("FS-SE3", "sdcard/enemyinfectedswarm_chr.bin")
.const sprEnemyMiner = AddAsset("FS-SE4", "sdcard/enemyminer_chr.bin")
.const sprBull = AddAsset("FS-S1", "sdcard/bull_chr.bin")
.const sprPlayer = AddAsset("FS-S2", "sdcard/playerrot_chr.bin")
.const sprExplo = AddAsset("FS-S3", "sdcard/explosion_chr.bin")
.const sprPickup = AddAsset("FS-S4", "sdcard/pickup_chr.bin")
.const sprHudTop = AddAsset("FS-S5", "sdcard/hudtop_chr.bin")
.const sprHudNumbers = AddAsset("FS-S6", "sdcard/hudNumbers_chr.bin")
.const sprSpawn = AddAsset("FS-S7", "sdcard/spawnin_chr.bin")

.print "--------"

.const blobsBegin = SetAssetAddr($00000, $30000)
.const iffl0 = AddAsset("FS-IFFL0", "sdcard/data.bin.addr.mc")

.print "--------"

#import "includes/layers_code.s"
#import "includes/assets_code.s"
#import "includes/system_code.s"
#import "includes/sdcard.s"
#import "includes/fastLoader.s"
#import "includes/decruncher.s"
#import "includes/rrbspr_code.s"
#import "includes/keyb_code.s"

// ------------------------------------------------------------
//
.enum {GStateTitles}
.var GSIniStateList = List().add(gsIniTitles)
.var GSUpdStateList = List().add(gsUpdTitles)
.var GSDrwStateList = List().add(gsDrwTitles)

// ------------------------------------------------------------
//
.segment Code "Entry"
Entry: 
{
	lda #$00
	sta FadeComplete
	sta VBlankCount
	sta Tmp7

	jsr System.Initialization1

 	sei

	lda #$7f
    sta $dc0d
    sta $dd0d

    lda $dc0d
    lda $dd0d

    lda #<irqFadeOutHandler
    sta $fffe
    lda #>irqFadeOutHandler
    sta $ffff

    lda #$01
    sta $d01a

    lda #$08
	sta $d012

    cli

	// initialise fast load (start drive motor)
	jsr fl_init

	LoadFile(bg0Chars.addr + iffl0.crunchAddress, iffl0.filenamePtr)
	DecrunchFile(bg0Chars.addr + iffl0.crunchAddress, bg0Chars.addr)

	// done loading. stop drive motor
	jsr fl_exit

	// wait until fade is complete. loading in xemu will have already ended by now.
!:	lda FadeComplete
	beq !-

	// Update screen positioning if PAL/NTSC has changed
	jsr System.CenterFrameHorizontally
	jsr System.CenterFrameVertically

 	sei

	jsr System.Initialization2

	VIC4_SetRowWidth(LOGICAL_ROW_SIZE)
	VIC4_SetNumCharacters(LOGICAL_ROW_SIZE/2)
	VIC4_SetNumRows(NUM_ROWS)

	VIC4_SetScreenLocation(SCREEN_RAM)

 	ldx #LayerEOL.id
	lda #<SCREEN_WIDTH
	jsr Layers.SetXPosLo
	lda #>SCREEN_WIDTH
	jsr Layers.SetXPosHi

	ldx #LayerD.id
	lda #$00
	jsr Layers.SetXPosLo
	lda #$00
	jsr Layers.SetXPosHi

	jsr LayerDClear

	jsr Layers.UpdateData.InitEOL

	jsr ClearPalette

	TextSetPos(0,0)
//	TextPrintMsg(imessage)

	lda #GStateTitles
	jsr SwitchGameStates

	jsr InitBGMap

	// Enable Audio DMA
 	lda #$80
 	sta $d711
	
	lda #$7f                // kill CIA interupts
    sta $dc0d
    sta $dd0d

    lda $dc0d               // read interupts to clear them
    lda $dd0d

    // change pointer to new interrupt
    lda #>irqBotHandler
    sta $ffff
    lda #<irqBotHandler
    sta $fffe

    // Disable RSTDELENS
    lda #%01000000
    trb $d05d

    // get the vic II to do raster interupts
    lda #$01
    sta $d01a

    // set the interrupt to line 250
    jsr SetIRQBotPos

    cli

mainloop:
	lda VBlankCount
!:
	cmp VBlankCount
	beq !-

	DbgBord(1)

	// Update the display buffers
	jsr UpdateDisplay

	jsr RRBSpr.Clear

	// jsr Player.UpdDPad

	// Run the update
	lda GameState
	asl
	tax
	jsr (GSUpdStateTable,x)

	jsr Camera.CalcParallax

	DbgBord(1)

	ldx #Layer1.id
	lda Camera.XScroll1+0
	jsr Layers.SetFineScroll

	// Run the draw
	lda GameState
	asl
	tax
	jsr (GSDrwStateTable,x)

	// TextSetPos(0,4)
	// lda Player.DPadClick
	// jsr PrintHexByte

	DbgBord(0)

	// Wait a couple of frames before enabling screen to give screen time to properly redraw itself and not show garbage
	lda VBlankCount
	cmp #$05
	bne !+
	jsr System.EnableScreen

!:	jmp mainloop
}

// set fadecomplete to 0 for the fade-in
InitFadeIn: {
	lda #$00
	sta FadeComplete
	sta VBlankCount
	sta Tmp7
	rts
}

SwitchGameStates: {
	sta GameState
	asl
	tax
	jsr (GSIniStateTable,x)
	rts
}

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

		lda FadeComplete
		bne FadeoutCompleteIRQ

		lda Tmp7
		cmp #$03
		bne !+
		jsr DecreasePalette
		lda #$00
		sta Tmp7
!:		inc VBlankCount
		inc Tmp7
		lda VBlankCount
		cmp #60
		bne irqFadeOutHandlerEnd

FadeoutCompleteIRQ:
		lda #$01
		sta FadeComplete
		lda #$00								// code to run when fadeout is complete
		sta $d020
		sta $d020
		sta VBlankCount
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
		sta Tmp7+0
		lda #>(fadeTabStart+1)
		adc #$00
		sta Tmp7+1

        ldx #$00
!IncreasePaletteloop:
		.for(var p=0; p<14; p++) 
		{
			lda Palette + (p * $30) + $000,x
			tay
			lda swapNybbleTab,y
			tay
			lda (Tmp7),y
			sta $d100 + (p * $10),x

			lda Palette + (p * $30) + $010,x
			tay
			lda swapNybbleTab,y
			tay
			lda (Tmp7),y
			sta $d200 + (p * $10),x

			lda Palette + (p * $30) + $020,x
			tay
			lda swapNybbleTab,y
			tay
			lda (Tmp7),y
			sta $d300 + (p * $10),x
		}

		lda #$ff				// flash
		tay
		lda swapNybbleTab,y
		tay
		lda (Tmp7),y
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

	dec IRQCount
	lbeq _lastIRQ

	// ldx IRQCount
	// lda rngtable,x
	// sta $d000

//	lda IRQPos
//	sta $d001

	lda Palette + $0e
	sta $d10e
	lda Palette + $1e
	sta $d20e
	lda Palette + $2e
	sta $d30e

	clc
	lda IRQPos
	adc #$02
	sta IRQPos
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

	inc VBlankCount

	lda FadeComplete
	bne SkipFadeIn

	lda VBlankCount
	asl
	asl
	cmp #$00-4
	bcc !+
	lda #$01
	sta FadeComplete
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
    sta IRQCount

    // set the interrupt position
    lda System.IRQTopPos
    sta IRQPos
    sta $d012
    lda #$80
    trb $d011

	// clear the signal
	lsr $d019

	pla

	rti
}

UpdateDisplay:
{
	DbgIncBord()
	jsr Layers.UpdateData.UpdateLayer1

	DbgIncBord()
	jsr Layers.UpdateData.UpdateRRB

	DbgIncBord()
	jsr Layers.UpdateData.UpdateLayerD

	DbgIncBord()
	jsr Layers.UpdateScrollPositions

	DbgDecBord()
	DbgDecBord()
	DbgDecBord()
	DbgDecBord()
	DbgDecBord()
	DbgDecBord()

	rts
}

// ----------------------------------------------------------------------------
//
InitBGMap:
{
	.var chr_ptr = Tmp					// 32bit
	.var attrib_ptr = Tmp1				// 32bit
	.var line_stride = Tmp2				// 16bit

	.var tiles_ptr = Tmp2+2				// 16bit
	.var map_base = Tmp3				// 16bit
	.var map_offs = Tmp3+2				// 16bit
	.var map_ptr = Tmp4					// 16bit
	.var chr_offs = Tmp4+2				// 16bit
	.var palIndx = Tmp5					// 8bit
	.var line_delta = Tmp5+2			// 16bit
	.var tile_map = Tmp6				// 16bit

	lda #<[$3e]
	sta offsWrapLo
	lda #>[$3e]
	sta offsWrapHi
	lda #<[$40]
	sta baseAddLo
	lda #>[$40]
	sta baseAddHi
	lda #$20
	sta colCount
	_set16im(BGROWSIZE, line_delta)
	_set16im(BGROWSIZE*2, line_stride)		// we fill the buffer 2 lines at a time
	_set16im(Bg0Tiles, tile_map)
	_set16im((bg0Chars.addr/64), chr_offs)
    _set16im(BgMap, map_base)
    _set32im(BGMap1TileRAM, chr_ptr)
    _set32im(BGMap1AttribRAM, attrib_ptr)
	_set8im((Layer1.palIdx<<4) | $0f, palIndx)
    jsr InitMap

    rts

InitMap:
    // y = line (0 - 5)
    ldy #0

_row_loop:

    tya
    pha

    // reset the map offset
	_set16im(0, map_offs)

    ldx #0
    ldz #0

_line_loop: 

    // map_ptr = map_base + map_offs
    _add16(map_base, map_offs, map_ptr)

    // calculate the tile ptr (map_ptr) * 4
    //
    ldy #0
    lda (map_ptr),y             // Get the tile #
    sta tiles_ptr
    iny
    lda (map_ptr),y
    sta tiles_ptr+1

    asl tiles_ptr				// tiles are 4 bytes
    rol tiles_ptr+1
    asl tiles_ptr
    rol tiles_ptr+1

    _add16(tiles_ptr, tile_map, tiles_ptr)

    ldy #0

    // two rows per tile
	lda #$08
	sta ((attrib_ptr)),z
    clc
    lda (tiles_ptr),y
    adc chr_offs+0
    sta ((chr_ptr)),z			// + 0
    iny
    inz
    lda (tiles_ptr),y
    adc chr_offs+1
    sta ((chr_ptr)),z			// + 1
	lda palIndx
	sta ((attrib_ptr)),z
    iny
    dez

    _add16(chr_ptr, line_delta, chr_ptr)
    _add16(attrib_ptr, line_delta, attrib_ptr)

	lda #$08
	sta ((attrib_ptr)),z
    clc
    lda (tiles_ptr),y
    adc chr_offs+0
    sta ((chr_ptr)),z			// BGROWSIZE + 0
    iny
    inz
    lda (tiles_ptr),y
    adc chr_offs+1
    sta ((chr_ptr)),z			// BGROWSIZE + 1
	lda palIndx
	sta ((attrib_ptr)),z
    iny

    // indexes 0 and 1 have been filled, advance to 2
    inz

    _sub16(chr_ptr, line_delta, chr_ptr)
    _sub16(attrib_ptr, line_delta, attrib_ptr)

    _add16im(map_offs, 2, map_offs)
    lda map_offs+0
    and offsWrapLo:#<[$0f]
    sta map_offs+0
    lda map_offs+1
    and offsWrapHi:#>[$0f]
    sta map_offs+1

    inx
    cpx colCount:#$20
    lbne _line_loop

    // move map_base down a row
    clc
    lda map_base+0
    adc baseAddLo:#<[2*16]
    sta map_base+0
    lda map_base+1
    adc baseAddHi:#>[2*16]
    sta map_base+1

    // move down 2 rows
    _add16(chr_ptr, line_stride, chr_ptr)
    _add16(attrib_ptr, line_stride, attrib_ptr)

    pla
    tay

    iny
    cpy #NUM_ROWS/2
    lbne _row_loop

    rts
}

ClearPalette: {
		//Bit pairs = CurrPalette, TextPalette, SpritePalette, AltPalette
		lda #%00000010 //Edit=%00, Text = %00, Sprite = %01, Alt = %00
		sta $d070 

		lda #$00
		ldx #$00
!:		sta $d100,x
		sta $d200,x
		sta $d300,x

		inx 
		bne !-

		rts
}

//
LayerDClear: {
	.var chr_ptr = Tmp					// 16bit
	.var attrib_ptr = Tmp+2				// 16bit

	_set16im(LayerDTileBuffer, chr_ptr)
	_set16im(LayerDAttribBuffer, attrib_ptr)

	ldz #$00
!rloop:

		ldy #$00

		ldx #$00
	!cloop:
		lda #$20
		sta (chr_ptr),y
		lda #$00
		sta (attrib_ptr),y
		iny
		lda #$00
		sta (chr_ptr),y
		lda #$07
		sta (attrib_ptr),y
		iny

		inx
		cpx #LayerD.num
		bne !cloop-

	_add16im(chr_ptr, LayerD.ChrSize, chr_ptr)
	_add16im(attrib_ptr, LayerD.ChrSize, attrib_ptr)

	inz
	cpz #NUM_ROWS
	bne !rloop-

	rts
}

//
DrawHUD: {
	.var chr_ptr = Tmp					// 16bit
	.var attrib_ptr = Tmp+2				// 16bit
	.var o_chr_offs = Tmp1				// 16bit
	.var chr_offs = Tmp1+2				// 16bit

	_set16im((hudChars.addr/64), o_chr_offs)

	_set16im(LayerDTileBuffer + 14 + ((NUM_ROWS-3) * LayerD.ChrSize), chr_ptr)
	_set16im(LayerDAttribBuffer + 14 + ((NUM_ROWS-3) * LayerD.ChrSize), attrib_ptr)

	jsr drawBlock

	rts

	drawBlock: 
	{
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
		cpz #3
		bne !rloop-

		rts
	}
}

PrintHexByte: {
	pha
	and #$0f
	tax
	lda hexStr,x
	sta tmpstr+1
	pla
	lsr
	lsr
	lsr
	lsr
	and #$0f
	tax
	lda hexStr,x
	sta tmpstr+0

	TextPrintMsg(tmpstr)

	clc
	lda TextPosX
	adc #$02
	sta TextPosX

	rts
}

// ----------------------------------------------------------------------------
//
LayerDPrintMsg: {
	.var chr_ptr = Tmp
	.var attrib_ptr = Tmp+2

	//
	ldx TextPosY

	clc
	lda #<LayerDTileBuffer
	adc LayerDRowOffsLo,x
	sta chr_ptr+0
	lda #>LayerDTileBuffer
	adc LayerDRowOffsHi,x
	sta chr_ptr+1

	clc
	lda #<LayerDAttribBuffer
	adc LayerDRowOffsLo,x
	sta attrib_ptr+0
	lda #>LayerDAttribBuffer
	adc LayerDRowOffsHi,x
	sta attrib_ptr+1

	lda TextPosX
	asl
	tay

	ldz #$00

!loop:

	lda (TextPtr),z
	beq !exit+

	inz

	cmp #'\n'
	beq !dowrap+

	sta (chr_ptr),y
	lda #$00
	sta (attrib_ptr),y
	iny
	lda #$0b
	sta (attrib_ptr),y
	iny
	cpy #(LayerD.num)*2
	bcc !nowrap+

!dowrap:

	inx
	cpx #NUM_ROWS
	bcs !exit+

	// 
	clc
	lda #<LayerDTileBuffer
	adc LayerDRowOffsLo,x
	sta chr_ptr+0
	lda #>LayerDTileBuffer
	adc LayerDRowOffsHi,x
	sta chr_ptr+1

	clc
	lda #<LayerDAttribBuffer
	adc LayerDRowOffsLo,x
	sta attrib_ptr+0
	lda #>LayerDAttribBuffer
	adc LayerDRowOffsHi,x
	sta attrib_ptr+1

	lda TextPosX
	asl
	tay

!nowrap:
	jmp !loop-

!exit:

	rts
}

.encoding "screencode_mixed"
testTxt1:
	.text "firstshot"
	.byte $ff
testTxt2:
	.text "[press fire to start]"
	.byte $ff

chrWide:
	.byte $10,$10,$10,$0f,$10,$0f,$0d,$10,$10,$07,$0c,$10,$0c,$11,$10,$11
	.byte $10,$11,$10,$10,$0f,$10,$10,$11,$0f,$10,$10,$10,$08,$10,$10,$10
	.byte $08,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10
	.byte $10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10,$10

GetRandom: {
	phx
	inc RngIndx
	ldx RngIndx
	lda rngtable,x
	plx
	rts
}

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

#import "camera.s"
#import "gsTitles.s"

.segment Data "Text"
.encoding "screencode_mixed"
hexStr:		.text @"0123456789abcdef"
			.byte $00

tmpstr:		.text @"00"
			.byte $00

.encoding "ascii"

RngIndx:
	.byte $00

rngtable:
	.fill 256, ((random() * 2.0) - 1.0) * 127

sintable2:
	.fill 256, (sin((i/256) * PI * 2) * 31)
costable2:
	.fill 256, (cos((i/256) * PI * 2) * 31)


.segment Data "GameState"
GSIniStateTable:
	.fillword GSIniStateList.size(), GSIniStateList.get(i)
GSUpdStateTable:
	.fillword GSUpdStateList.size(), GSUpdStateList.get(i)
GSDrwStateTable:
	.fillword GSDrwStateList.size(), GSDrwStateList.get(i)

.segment Data "RRB Tile Clear"
RRBTileClear: {
	.for(var r=0; r<LayerRRB.DataSize/2; r++) {
		// GOTOX position
		.byte <SCREEN_WIDTH,>SCREEN_WIDTH
	}
}

.segment Data "RRB Attrib Clear"
RRBAttribClear: {
	.for(var r=0; r<LayerRRB.DataSize/2; r++) {
		// GOTOX position
		.byte $94,$00
	}
}

.segment Data "Palettes"
Palette:
	.import binary "./sdcard/font_pal.bin"
	.import binary "./sdtest2/bg20_pal.bin"

.segment Data "BgMap Buffer"
BgMap:
	.import binary "./sdtest2/bg2_LV0L0_map.bin"

.segment Data "Bg0 Tiles"
Bg0Tiles:
	.import binary "./sdtest2/bg20_tiles.bin"

.segment Data "tttYList Tables"
tttYListLo:
	.fill 4, <[(i * (14*64))]
tttYListHi:
	.fill 4, >[(i * (14*64))]

.segment Data "LayerNCM Tables"
LayerNCMRowOffsLo:
	.fill NUM_ROWS, <[(i * Layer1.ChrSize)]
LayerNCMRowOffsHi:
	.fill NUM_ROWS, >[(i * Layer1.ChrSize)]

.segment Data "LayerD Tables"
LayerDRowOffsLo:
	.fill NUM_ROWS, <[(i * LayerD.ChrSize)]
LayerDRowOffsHi:
	.fill NUM_ROWS, >[(i * LayerD.ChrSize)]

.segment Mapped8000 "LayerD Work Ram"
LayerDTileBuffer:
	.fill LayerD.ChrSize * NUM_ROWS, $00
LayerDAttribBuffer:
	.fill LayerD.ChrSize * NUM_ROWS, $00

.segment Mapped8000 "RRB Work Ram"
RRBCount:
	.fill NUM_ROWS, 0
RRBTileRowTableLo:
	.fill NUM_ROWS, 0
RRBTileRowTableHi:
	.fill NUM_ROWS, 0
RRBAttribRowTableLo:
	.fill NUM_ROWS, 0
RRBAttribRowTableHi:
	.fill NUM_ROWS, 0

.segment RRBWorkRam "RRB Working Buffers"
RRBTileBuffer:										// Layer RRB
	.fill LayerRRB.DataSize * NUM_ROWS, $00
RRBAttribBuffer:
	.fill LayerRRB.DataSize * NUM_ROWS, $00

.segment MapRam "Map RAM"
BGMap1TileRAM:
	.fill (BGROWSIZE*NUM_ROWS), $00
BGMap1AttribRAM:
	.fill (BGROWSIZE*NUM_ROWS), $00

.segment ScreenRam "Screen RAM"
	.fill (LOGICAL_ROW_SIZE*NUM_ROWS), $00

