// Only Segments Code and Data are included in the .prg, BSS and ZP are virtual
// and must be proerly initialized.
//
.file [name="startup.prg", type="bin", segments="Code,Data"]

#define USE_DBG

// ------------------------------------------------------------
// Memory layout
//
.const COLOR_OFFSET = $0800		// Offset ColorRam to make bank $10000 contiguous
.const COLOR_RAM = $ff80000 + COLOR_OFFSET

.const SCREEN_RAM = $50000		// 

.const CHARS_RAM = $10000

// ------------------------------------------------------------
// Defines to describe the screen size
//
// If you use H320 then SCREEN_WIDTH much be <= 360, otherwise <= 720
#define H320
.const SCREEN_WIDTH = 256

// If you use V200 then SCREEN_HEIGHT much be <= 240, otherwise <= 480
#define V200
.const SCREEN_HEIGHT = 200

// ------------------------------------------------------------
//
.segmentdef Zeropage [start=$02, min=$02, max=$fb, virtual]
.segmentdef Code [start=$2000, max=$7fff]
.segmentdef Data [start=$a000, max=$cfff]
.segmentdef BSS [start=$e000, max=$f400, virtual]

.segmentdef ScreenRam [start=SCREEN_RAM, virtual]
.segmentdef PixieWorkRam [startAfter="ScreenRam", max=SCREEN_RAM+$ffff, virtual]
.segmentdef MapRam [startAfter="PixieWorkRam", max=SCREEN_RAM+$ffff, virtual]

.cpu _45gs02				

#import "includes/m65macros.s"

#import "includes/layers_Functions.s"
#import "includes/assets_Functions.s"

.print "TOP_BORDER = " + TOP_BORDER

// ------------------------------------------------------------
// Layer constants
//
// Horizontally scrolling NCM needs full screen width + 1 tile to shift in when scrolling
//
.const NCM_TILES_WIDE = (SCREEN_WIDTH/16) + 1

// Vertically we want to show the full screen height (used to define the top and bottom borders)
// but the actual number of rows is + 1 so we can shift in the new row when scrolling
//
.const NUM_ROWS = (SCREEN_HEIGHT / 8) + 1

// Maximum number of Pixie words use per row, 1 pixie is 2 words (GOTOX + CHAR)
//
.const NUM_PIXIES = 64						// Must be < 256
.const NUM_PIXIEWORDS = NUM_PIXIES * 2

// ------------------------------------------------------------
// Layer layout for this example
//
// 1) BG layer for background
// 2) Pixie layer for you know, pixies
//
// 3) Always end with EOL layer
//
.const Layer1 = Layer_BG("bg_level", NCM_TILES_WIDE, true, 1)
.const LayerPixie = Layer_PIXIE("pixie", NUM_PIXIEWORDS, 1)
.const LayerEOL = Layer_EOL("eol")

// ------------------------------------------------------------
// Static BG Map sizes, in this example we are expanding the tile / map
// set into a static buffer, for a real game you'd want to be more fancy
//
.const BGROWSIZE = (512 / 16) * 2
.const BGNUMROWS = (2048 / 8)

.const MAXXBOUNDS = 512 - SCREEN_WIDTH
.const MAXYBOUNDS = 2048 - SCREEN_HEIGHT

// ------------------------------------------------------------
// Number of NCM palettes that we are using
//
.enum {
	PAL_FONTHUD,
	PAL_BG0,

	NUM_PALETTES
}

// ------------------------------------------------------------
//
.segment Zeropage "Main zeropage"

Tmp:			.word $0000,$0000		// General reusable data (Don't use in IRQ)
Tmp1:			.word $0000,$0000
Tmp2:			.word $0000,$0000
Tmp3:			.word $0000,$0000
Tmp4:			.word $0000,$0000
Tmp5:			.word $0000,$0000
Tmp6:			.word $0000,$0000

// ------------------------------------------------------------
//
.segment BSS "Main"

GameState:		.byte $00				// Titles / Play / HiScore etc
GameSubState:	.byte $00
GameStateTimer:	.byte $00
GameStateData:	.byte $00,$00,$00

DPad:			.byte $00
DPadClick:		.byte $00

//--------------------------------------------------------
// Main
//--------------------------------------------------------
.segment Code

* = $2000
	jmp Entry

.print "--------"

.const bgCharsBegin = SetAssetAddr(CHARS_RAM, $40000)
.const bg0Chars = AddAsset("FS-C0", "sdcard/bg20_chr.bin")
.const bg0Map = AddAsset("FS-C0", "sdcard/bg2_LV0L0_map.bin")
.const bg0Tiles = AddAsset("FS-C0", "sdcard/bg20_tiles.bin")

.const sprFont = AddAsset("FS-F0", "sdcard/font_chr.bin")

.print "--------"

.const blobsBegin = SetAssetAddr($00000, $40000)
.const iffl0 = AddAsset("FS-IFFL0", "sdcard/data.bin.addr.mc")

.print "--------"

#import "Irq.s"

#import "includes/layers_code.s"
#import "includes/assets_code.s"
#import "includes/system_code.s"
#import "includes/fastLoader.s"
#import "includes/decruncher.s"
#import "includes/keyb_code.s"
#import "includes/pixie_code.s"

// ------------------------------------------------------------
//
.enum {GStateTitles, GStatePlay}
.var GSIniStateList = List().add(gsIniTitles, gsIniPlay)
.var GSUpdStateList = List().add(gsUpdTitles, gsUpdPlay)
.var GSDrwStateList = List().add(gsDrwTitles, gsDrwPlay)

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

    lda #<Irq.irqBotHandler
    sta $fffe
    lda #>Irq.irqBotHandler
    sta $ffff

    lda #$01
    sta $d01a

	jsr Irq.SetIRQBotPos

    cli

	// Wait for IRQ before disabling the screen
	WaitVblank()

	jsr System.DisableScreen

	lda #$00
	sta $d020

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

	jsr InitPalette

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

	jsr InitDPad
	
mainloop:
	WaitVblank()

	DbgBord(4)

	// Update the display buffers for the coming frame, this DMAs the BG layer and
	// ALL pixie data and sets the X and Y scroll values
	//
	jsr UpdateDisplay

	DbgBord(0)

	// From this point on we update and draw the coming frame, this gives us a whole
	// frame to get all of the logic and drawing done.
	//

	// Clear the work Pixie ram using DMA
	jsr ClearWorkPixies

	// Scan the keyboard and joystick 2
	jsr UpdateDPad

	// Run the update
	lda GameState
	asl
	tax
	jsr (GSUpdStateTable,x)

	// Update scroll values for the next frame
	ldx #Layer1.id
	lda Camera.XScroll+0
	jsr Layers.SetFineScroll

	DbgBord(7)

	// Run the draw, this will add all of the pixies for the next frame
	lda GameState
	asl
	tax
	jsr (GSDrwStateTable,x)

	DbgBord(0)

	// If the frame is disabled, enable it, this ensure first frame of garbage isn't seen
	lda #FlEnableScreen
	bit System.Flags
	bne skipEnable

	jsr System.EnableScreen

skipEnable:

	jmp mainloop
}

// ------------------------------------------------------------
//
SwitchGameStates: {
	sta GameState
	asl
	tax
	jsr (GSIniStateTable,x)
	rts
}

// ------------------------------------------------------------
//
InitDPad: {

	lda #$00
	sta DPad
	sta DPadClick

	rts
}

UpdateDPad: {
	// Scan the keyboard
	jsr ScanKeyMatrix

	lda DPad
	sta oldDPad

	lda #$00
	sta DPad

	lda #$01
	bit $dc00
	bne _not_j2_up

	lda #$01
	tsb DPad
	bra _not_up

_not_j2_up:

	lda ScanResult+1
	and #$04
	bne _not_up

	lda #$01
	tsb DPad

_not_up:

	lda #$02
	bit $dc00
	bne _not_j2_down

	lda #$02
	tsb DPad
	bra _not_down

_not_j2_down:

	lda ScanResult+1
	and #$10
	bne _not_down

	lda #$02
	tsb DPad

_not_down:

	lda #$04
	bit $dc00
	bne _not_j2_left

	lda #$04
	tsb DPad
	bra _not_left

_not_j2_left:

	lda ScanResult+5
	and #$80
	bne _not_left

	lda #$04
	tsb DPad

_not_left:

	lda #$08
	bit $dc00
	bne _not_j2_right

	lda #$08
	tsb DPad
	bra _not_right

_not_j2_right:

	lda ScanResult+5
	and #$10
	bne _not_right

	lda #$08
	tsb DPad

_not_right:

	lda #$10
	bit $dc00
	bne _not_j2_fire

	lda #$10
	tsb DPad
	bra _not_fire

_not_j2_fire:

	lda ScanResult+6
	and #$80
	bne _not_fire

	lda #$10
	tsb DPad

_not_fire:

	lda ScanResult+0
	and #$40
	bne _not_F5

	lda #$20
	tsb DPad

_not_F5:

	lda ScanResult+0
	and #$08
	bne _not_F7

	lda #$40
	tsb DPad

_not_F7:

	lda oldDPad:#$00
	eor DPad
	and DPad
	sta DPadClick
	
	rts
}

// ------------------------------------------------------------
//
BgMap1:
.dword 	BGMap1TileRAM
.dword 	BGMap1AttribRAM
.word 	BGROWSIZE
.word	$0040

UpdateDisplay:
{
	ldx #Layer1.id
	ldy #<BgMap1
	ldz #>BgMap1
	jsr Layers.UpdateData.UpdateLayer

	jsr Layers.UpdateData.UpdatePixie

	jsr Layers.UpdateScrollPositions

	// Set the fine Y scroll by moving TextYPos up
	//
	lda Camera.YScroll+0
	and #$07
#if V200
	asl						// When in H200 mode, move 2x the number of pixels
#endif
	sta shiftUp

	// Modify the TextYPos by shifting it up
	sec
	lda System.TopBorder+0
	sbc shiftUp:#$00
	sta $d04e
	lda System.TopBorder+1
	sbc #$00
	and #$0f
	sta $d04f

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

    _set32im(BGMap1TileRAM, chr_ptr)		// map is decompressed to this location
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
    cpy #BGNUMROWS/2
    lbne _row_loop

    rts
}

// ------------------------------------------------------------
//
InitPalette: {
	//Bit pairs = CurrPalette, TextPalette, SpritePalette, AltPalette
	lda #%00000000 //Edit=%00, Text = %00, Sprite = %01, Alt = %00
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

	lda #$00
	sta $d100
	sta $d200
	sta $d300

	rts
}

// ------------------------------------------------------------
//
#import "camera.s"
#import "pixieText.s"
#import "gsTitles.s"
#import "gsPlay.s"

.segment Data "GameState Tables"
GSIniStateTable:
	.fillword GSIniStateList.size(), GSIniStateList.get(i)
GSUpdStateTable:
	.fillword GSUpdStateList.size(), GSUpdStateList.get(i)
GSDrwStateTable:
	.fillword GSDrwStateList.size(), GSDrwStateList.get(i)

// ------------------------------------------------------------
//
.segment Code "RRB Clear Data"
ClearPixieTile:
	.for(var c = 0;c < NUM_PIXIEWORDS;c++) 
	{
		.byte <SCREEN_WIDTH,>SCREEN_WIDTH
	}

ClearPixieAttrib:
	.for(var c = 0;c < NUM_PIXIEWORDS;c++) 
	{
		.byte $90,$00
	}

.segment Data "Palettes"
Palette:
	.import binary "./sdcard/font_pal.bin"
	.import binary "./sdcard/bg20_pal.bin"

.segment Data "BgMap Buffer"
BgMap:
	.import binary "./sdcard/bg2_LV0L0_map.bin"

.segment Data "Bg0 Tiles"
Bg0Tiles:
	.import binary "./sdcard/bg20_tiles.bin"

// ------------------------------------------------------------
// Ensure these tables DONOT straddle a bank address
//
.segment PixieWorkRam "Pixie Work RAM"
PixieWorkTiles:
	.fill (LayerPixie.DataSize * NUM_ROWS), $00
PixieWorkAttrib:
	.fill (LayerPixie.DataSize * NUM_ROWS), $00

.segment MapRam "Map RAM"
BGMap1TileRAM:
	.fill (BGROWSIZE*BGNUMROWS), $00
BGMap1AttribRAM:
	.fill (BGROWSIZE*BGNUMROWS), $00

.segment ScreenRam "Screen RAM"
	.fill (LOGICAL_ROW_SIZE*NUM_ROWS), $00

