// Only Segments Code and Data are included in the .prg, BSS and ZP are virtual
// and must be proerly initialized.
//
.file [name="startup.prg", type="bin", segments="Code,Data"]
.cpu _45gs02				

#define USE_DBG				// enable to see raster costs

// ------------------------------------------------------------
// Memory layout
//
.const COLOR_OFFSET = $0800		// Offset ColorRam to make bank $10000 contiguous
.const COLOR_RAM = $ff80000 + COLOR_OFFSET

.const CHARS_RAM = $10000		// all bg chars / pixie data goes here
.const MAP_RAM = $40000			// bg map data goes here
.const SCREEN_RAM = $50000		// screen ram / pixie work ram goes here

.segmentdef Zeropage [start=$02, min=$02, max=$fb, virtual]
.segmentdef Code [start=$2000, max=$7fff]
.segmentdef Data [start=$a000, max=$cfff]
.segmentdef BSS [start=$e000, max=$f400, virtual]

.segmentdef MapRam [start=MAP_RAM, max=SCREEN_RAM-1, virtual]

.segmentdef ScreenRam [start=SCREEN_RAM, virtual]
.segmentdef PixieWorkRam [startAfter="ScreenRam", max=SCREEN_RAM+$ffff, virtual]

// ------------------------------------------------------------
// Defines to describe the screen size
//
.const SCREEN_WIDTH = 320
.const SCREEN_HEIGHT = 208

.const PLAY_SCREEN_WIDTH = 320
.const PLAY_SCREEN_HEIGHT = 208

// ------------------------------------------------------------
//
#import "includes/m65macros.s"

#import "includes/layers_Functions.s"
#import "includes/layout_Functions.s"
#import "includes/assets_Functions.s"

// ------------------------------------------------------------
// Layer constants
//

// Maximum number of Pixie words use per row, 1 pixie is 2 words (GOTOX + CHAR)
//
.const NUM_PIXIES = 48						// Must be < 256
.const NUM_PIXIEWORDS = NUM_PIXIES * 2

// ------------------------------------------------------------
// Layer layout for title screen example
//
// 1) BG layer for background
// 2) Pixie layer for you know, pixies
//
// 3) Always end with EOL layer
//
.const Layout1 = NewLayout("titles", SCREEN_WIDTH, SCREEN_HEIGHT, (SCREEN_HEIGHT / 8) + 1)
.const Layout1_BG = Layer_BG("bg_level", (SCREEN_WIDTH/16) + 1, true, 1)
.const Layout1_Pixie = Layer_PIXIE("pixie", NUM_PIXIEWORDS, 1)
.const Layout1_EOL = Layer_EOL("eol")
.const Layout1end = EndLayout(Layout1)

// ------------------------------------------------------------
// Layer layout for game screen example
//
// Dual horizontally parallaxing layers with pixies
//
// 1) BG0 layer for background
// 1) BG1 layer for midground
// 2) Pixie layer for you know, pixies
//
// 3) Always end with EOL layer
//
.const Layout2 = NewLayout("play", PLAY_SCREEN_WIDTH, PLAY_SCREEN_HEIGHT, (PLAY_SCREEN_HEIGHT / 8))
.const Layout2_BG0 = Layer_BG("bg_level0", (PLAY_SCREEN_WIDTH/16) + 1, true, 1)
.const Layout2_BG1 = Layer_BG("bg_level1", (PLAY_SCREEN_WIDTH/16) + 1, true, 1)
.const Layout2_Pixie = Layer_PIXIE("pixie", NUM_PIXIEWORDS, 1)
.const Layout2_EOL = Layer_EOL("eol")
.const Layout2end = EndLayout(Layout2)

// ------------------------------------------------------------
// Layer layout for credits screen example
//
// Dual vertically and horizontally parallaxing layers with pixies,
// note that vertical parallax needs 2 layers per graphics layer!!!
//
// 1) BG0 layer for background
// 1) BG0 layer for background
// 1) BG1 layer for midground
// 1) BG1 layer for midground
// 2) Pixie layer for you know, pixies
//
// 3) Always end with EOL layer
//
.const Layout3 = NewLayout("credits", PLAY_SCREEN_WIDTH, PLAY_SCREEN_HEIGHT, (PLAY_SCREEN_HEIGHT / 8))
.const Layout3_BG0a = Layer_BG("bg_level0a", (PLAY_SCREEN_WIDTH/16) + 1, true, 1)
.const Layout3_BG0b = Layer_BG("bg_level0b", (PLAY_SCREEN_WIDTH/16) + 1, true, 1)
.const Layout3_BG1a = Layer_BG("bg_level1a", (PLAY_SCREEN_WIDTH/16) + 1, true, 1)
.const Layout3_BG1b = Layer_BG("bg_level1b", (PLAY_SCREEN_WIDTH/16) + 1, true, 1)
.const Layout3_Pixie = Layer_PIXIE("pixie", NUM_PIXIEWORDS, 1)
.const Layout3_BG2a = Layer_BG("bg_level2a", (PLAY_SCREEN_WIDTH/16) + 1, true, 1)
.const Layout3_BG2b = Layer_BG("bg_level2b", (PLAY_SCREEN_WIDTH/16) + 1, true, 1)
.const Layout3_EOL = Layer_EOL("eol")
.const Layout3end = EndLayout(Layout3)

// ------------------------------------------------------------
// Static BG Map sizes, in this example we are expanding the tile / map
// set into a static buffer, for a real game you'd want to be more fancy
//
.const BG0ROWSIZE = (256 / 16) * 2
.const BG0NUMROWS = (256 / 8)

.const BG1ROWSIZE = (512 / 16) * 2
.const BG1NUMROWS = (512 / 8)

.const BG2ROWSIZE = (512 / 16) * 2
.const BG2NUMROWS = (512 / 8)

.const MAXXBOUNDS = 512 - SCREEN_WIDTH
.const MAXYBOUNDS = 512 - SCREEN_HEIGHT

// ------------------------------------------------------------
// Number of NCM palettes that we are using
//
.enum {
	PAL_FONTHUD,
	PAL_BG0,
	PAL_BG1,
	PAL_BG2,

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
Tmp7:			.word $0000,$0000

// ------------------------------------------------------------
//
.segment BSS "Main"

RequestGameState:	.byte $00
GameState:			.byte $00				// Titles / Play / HiScore etc
GameSubState:		.byte $00
GameStateTimer:		.byte $00
GameStateData:		.byte $00,$00,$00

//--------------------------------------------------------
// Main
//--------------------------------------------------------
.segment Code

* = $2000
	jmp Entry

.print "--------"

.const bgCharsBegin = SetAssetAddr(CHARS_RAM, $40000)
.const bg0Chars = AddAsset("FS-C0", "sdcard/bg20_chr.bin")
.const bg1Chars = AddAsset("FS-C1", "sdcard/bg21_chr.bin")
.const bg2Chars = AddAsset("FS-C2", "sdcard/bg22_chr.bin")

.const sprFont = AddAsset("FS-F0", "sdcard/font_chr.bin")

.print "--------"

.const blobsBegin = SetAssetAddr($00000, $40000)
.const iffl0 = AddAsset("FS-IFFL0", "sdcard/data.bin.addr.mc")

.print "--------"

#import "includes/layers_code.s"
#import "includes/layout_code.s"
#import "includes/assets_code.s"
#import "includes/system_code.s"
#import "includes/fastLoader.s"
#import "includes/decruncher.s"
#import "includes/keyb_code.s"
#import "includes/pixie_code.s"

// ------------------------------------------------------------
//
.enum {GStateTitles, GStatePlay, GStateCredits}
.var GSIniStateList = List().add(gsIniTitles, gsIniPlay, gsIniCredits)
.var GSUpdStateList = List().add(gsUpdTitles, gsUpdPlay, gsUpdCredits)
.var GSDrwStateList = List().add(gsDrwTitles, gsDrwPlay, gsDrwCredits)

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

	VIC4_SetScreenLocation(SCREEN_RAM)

	// Initialize palette and bgmap data
	jsr InitPalette
	jsr InitBGMap

	TextSetPos(0,0)
//	TextPrintMsg(imessage)

	// Setup the initial game state
	lda #GStateTitles
	sta RequestGameState
	jsr SwitchGameStates

    // Disable RSTDELENS
    lda #%01000000
    trb $d05d

    // set the interrupt to line bottom position
    jsr Irq.SetIRQBotPos

	cli

	// initialize dpad data	
	jsr System.InitDPad
		
mainloop:
	WaitVblank()

	DbgBord(4)

	// !!!! - Update Buffers that will be seen next frame - !!!!
	//
	// Update the layer buffers for the coming frame, this DMAs the BG layer and
	// ALL pixie data and sets the X and Y scroll values
	//
	jsr Layout.ConfigureHW
	jsr Layout.UpdateBuffers

	// If the frame is disabled, enable it, this ensure first frame of garbage isn't seen
	lda #FlEnableScreen
	bit System.Flags
	bne skipEnable

	jsr System.EnableScreen

skipEnable:

	// Determine if we want to switch states, this is done here so that any
	// new layout requests are properly setup.
	//
	lda RequestGameState
	cmp GameState
	beq !+

	jsr SwitchGameStates

!:

	DbgBord(0)

	// !!!! - Prepare all data for next frame - !!!!
	//
	// From this point on we update and draw the coming frame, this gives us a whole
	// frame to get all of the logic and drawing done.
	//

	// Clear the work Pixie ram using DMA
	jsr ClearWorkPixies

	// Scan the keyboard and joystick 2
	jsr System.UpdateDPad

	// Run the update
	lda GameState
	asl
	tax
	jsr (GSUpdStateTable,x)

	DbgBord(7)

	// Run the draw, this will add all of the pixies for the next frame
	lda GameState
	asl
	tax
	jsr (GSDrwStateTable,x)

	DbgBord(0)

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
RenderNop: {
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
	sta $d110
	sta $d200
	sta $d210
	sta $d300
	sta $d310

	rts
}

// ------------------------------------------------------------
//
#import "irq.s"
#import "camera.s"
#import "pixieText.s"
#import "gsTitles.s"
#import "gsPlay.s"
#import "gsCredits.s"
#import "bgmap.s"

.segment Data "GameState Tables"
GSIniStateTable:
	.fillword GSIniStateList.size(), GSIniStateList.get(i)
GSUpdStateTable:
	.fillword GSUpdStateList.size(), GSUpdStateList.get(i)
GSDrwStateTable:
	.fillword GSDrwStateList.size(), GSDrwStateList.get(i)

// ------------------------------------------------------------
//
.segment Data "Palettes"
Palette:
	.import binary "./sdcard/font_pal.bin"
	.import binary "./sdcard/bg20_pal.bin"
	.import binary "./sdcard/bg21_pal.bin"
	.import binary "./sdcard/bg22_pal.bin"

// ------------------------------------------------------------
// Ensure these tables DONOT straddle a bank address
//
.segment PixieWorkRam "Pixie Work RAM"
PixieWorkTiles:
	.fill (Layout1_Pixie.DataSize * MAX_NUM_ROWS), $00
PixieWorkAttrib:
	.fill (Layout1_Pixie.DataSize * MAX_NUM_ROWS), $00

.segment ScreenRam "Screen RAM"
	.fill (MAX_SCREEN_SIZE), $00

