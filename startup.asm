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
.const SCREEN_WIDTH = 320

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
.const LayerRRB = Layer_RRB("rrb", 63, 1)				// This is capped at 127 max due to index register limitation
.const LayerEOL = Layer_EOL("eol")

// ------------------------------------------------------------
//
.const NUM_ROWS = SCREEN_HEIGHT / 8

.const BGROWSIZE = 32 * 2

// ------------------------------------------------------------
//
.enum {
	PAL_FONTHUD,
	PAL_BG0,

	NUM_PALETTES
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

GameState:		.byte $00				// Titles / Play / HiScore etc
GameSubState:	.byte $00
GameStateTimer:	.byte $00
GameStateData:	.byte $00,$00,$00

//--------------------------------------------------------
// Main
//--------------------------------------------------------
.segment Code

* = $2000
	jmp Entry

.print "--------"

.const bgCharsBegin = SetAssetAddr(CHARS_RAM, $30000)
.const bg0Chars = AddAsset("FS-C0", "sdtest2/bg20_chr.bin")
.const sprFont = AddAsset("FS-F0", "sdcard/font_chr.bin")

.print "--------"

.const blobsBegin = SetAssetAddr($00000, $30000)
.const iffl0 = AddAsset("FS-IFFL0", "sdcard/data.bin.addr.mc")

.print "--------"

#import "Irq.s"

#import "includes/layers_code.s"
#import "includes/assets_code.s"
#import "includes/system_code.s"
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
	jsr System.Initialization1

 	sei

	lda #$7f
    sta $dc0d
    sta $dd0d

    lda $dc0d
    lda $dd0d

    lda #<Irq.irqHandler
    sta $fffe
    lda #>Irq.irqHandler
    sta $ffff

    lda #$01
    sta $d01a

	jsr Irq.SetIRQBotPos

    cli

	jsr System.EnableScreen

	// Wait for IRQ before disabling the screen
	lda Irq.VBlankCount
!:
	cmp Irq.VBlankCount
	beq !-

	jsr System.DisableScreen

	// initialise fast load (start drive motor)
	jsr fl_init

	LoadFile(bg0Chars.addr + iffl0.crunchAddress, iffl0.filenamePtr)
	DecrunchFile(bg0Chars.addr + iffl0.crunchAddress, bg0Chars.addr)

	// done loading. stop drive motor
	jsr fl_exit
	
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

	jsr Layers.UpdateData.InitEOL

	jsr ClearPalette

	TextSetPos(0,0)
//	TextPrintMsg(imessage)

	lda #GStateTitles
	jsr SwitchGameStates

	jsr InitBGMap

    // Disable RSTDELENS
    lda #%01000000
    trb $d05d

    // set the interrupt to line bottom position
    jsr Irq.SetIRQBotPos

	cli

	infLoop()

mainloop:
	lda Irq.VBlankCount
!:
	cmp Irq.VBlankCount
	beq !-

	DbgBord(4)

	// Update the display buffers
	jsr UpdateDisplay

	DbgBord(5)

	jsr RRBSpr.Clear

	DbgBord(6)

	// jsr Player.UpdDPad

	// Run the update
	lda GameState
	asl
	tax
	jsr (GSUpdStateTable,x)

	jsr Camera.CalcParallax

	ldx #Layer1.id
	lda Camera.XScroll1+0
	jsr Layers.SetFineScroll

	DbgBord(7)

	// Run the draw
	lda GameState
	asl
	tax
	jsr (GSDrwStateTable,x)

	// TextSetPos(0,4)
	// lda Player.DPadClick
	// jsr PrintHexByte

	DbgBord(0)

	jmp mainloop
}

SwitchGameStates: {
	sta GameState
	asl
	tax
	jsr (GSIniStateTable,x)
	rts
}

UpdateDisplay:
{
	jsr Layers.UpdateData.UpdateLayer1

	jsr Layers.UpdateData.UpdateRRB

	jsr Layers.UpdateScrollPositions

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

		ldx #$00
!:
		.for(var p=0; p<NUM_PALETTES; p++) 
		{
			lda Palette + (p * $30) + $000,x
			sta $d100 + (p * $10),x
			lda Palette + (p * $30) + $010,x
			sta $d200 + (p * $10),x
			lda Palette + (p * $30) + $020,x
			sta $d300 + (p * $10),x
		}

		inx
		cpx #$10
		lbne !-

		rts
}

#import "camera.s"
#import "gsTitles.s"

.segment Data "GameState Tables"
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

