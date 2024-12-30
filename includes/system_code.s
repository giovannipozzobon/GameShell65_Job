//--------------------------------------------------------
//
.const FlEnableScreen = $01

//--------------------------------------------------------
// System
//
.namespace System
{

//--------------------------------------------------------
//
.segment BSS "System ZP"
TopBorder:		.word $0000
BotBorder:		.word $0000
TextYPos:		.word $0000
IRQBotPos:		.word $0000

Flags:			.byte $00

//--------------------------------------------------------
//
.segment BSS "System BSS"
DPad:				.byte $00
DPadClick:			.byte $00

//--------------------------------------------------------
//
.segment Code "System Code"
Initialization1:
{
	sei
	
	lda #$35
	sta $01

	enable40Mhz()
	enableVIC4Registers()
	disableCIAInterrupts()
	disableC65ROM()

	//Disable IRQ raster interrupts
	//because C65 uses raster interrupts in the ROM
	lda #$00
	sta $d01a

	//Disable hot register so VIC2 registers 
	lda #$80		
	trb $d05d			//Clear bit7=HOTREG

	// Inital IRQs at position $08 to avoid visible line 
	// when disabling the screen
	_set16im($08, IRQBotPos)

	cli

	rts
}

Initialization2:
{
	//Change VIC2 stuff here to save having to disable hot registers
	lda #%00000111
	trb $d016

    // Set RASLINE0 to 0 for the first VIC-II rasterline
    lda #%00111111
    trb $d06f

	// Disable VIC3 ATTR register to enable 8bit color
	lda #$20			//Clear bit5=ATTR
	trb $d031

	// Enable RAM palettes
	lda #$04			//Set bit2=PAL
	tsb $d030

	// Enable RRB double buffer
	lda #$80			//Clear bit7=NORRDEL
	trb $d051

	// Enable double line RRB to double the time for RRB operations 
	lda #$08			//Set bit3=V400
	tsb $d031
	lda #$40    		//Set bit6=DBLRR
	tsb $d051
	lda #$00    		//Set CHRYSCL = 0
	sta $d05b

	// Enable H320 mode, Super Extended Attributes and mono chars < $ff
	lda #%10000000		//Clear bit7=H640
	trb $d031

	lda #<COLOR_OFFSET	// set offset to colour ram so we can use the first 8kb for something else and $10000-$60000 is a continuous playground without the colour ram in the middle
	sta $d064			// this causes a 1 pixel bug in the bottom right of the screen, so commenting it out again for now.
	lda #>COLOR_OFFSET
	sta $d065

	lda #%00000101		//Set bit2=FCM for chars >$ff,  bit0=16 bit char indices
	tsb $d054

	rts
}

DisableScreen:
{
	lda #FlEnableScreen
	trb Flags

	lda #$00
	sta $d011
	rts
}

EnableScreen:
{
	lda #FlEnableScreen
	tsb Flags

	lda #$1b
	sta $d011
	rts
}

CenterFrameHorizontally:
{
	.var charXPos = Tmp				// 16bit

	_set16im(HORIZONTAL_CENTER, charXPos)
	_sub16(charXPos, Layout.LayoutWidth, charXPos)

	// SDBDRWDLSB,SDBDRWDMSB - Side Border size
	lda charXPos+0
	sta $d05c
	lda #%00111111
	trb $d05d
	lda charXPos+1
	and #%00111111
	tsb $d05d

	// TEXTXPOS - Text X Pos
	lda charXPos+0
	sta $d04c
	lda #%00001111
	trb $d04d
	lda charXPos+1
	and #%00001111
	sta $d04d

	rts
}

CenterFrameVertically: 
{
	.var verticalCenter = Tmp			// 16bit
	.var halfCharHeight = Tmp+2			// 16bit

	// The half height of the screen in rasterlines is (charHeight / 2) * 2
	_set16(Layout.LayoutHeight, halfCharHeight)

	// Figure out the vertical center of the screen

	// PAL values
	_set16im(304, verticalCenter)

	bit $d06f
	bpl isPal

	// NTSC values
	_set16im(242, verticalCenter)

isPal:

	_sub16(verticalCenter, halfCharHeight, TopBorder)
	_add16(verticalCenter, halfCharHeight, BotBorder)

	_set16(TopBorder, TextYPos)

	// hack!!
	// If we are running on real hardware then adjust char Y start up to avoid 2 pixel Y=0 bug
	lda $d60f
	and #%00100000
	beq !+

	_sub16im(TextYPos, 4, TextYPos)
	_sub16im(BotBorder, 1, BotBorder)

!:

	// Set these values on the hardware
	// TBDRPOS - Top Border
	lda TopBorder+0
	sta $d048
	lda #%00001111
	trb $d049
	lda TopBorder+1
	tsb $d049

	// BBDRPOS - Bot Border
	lda BotBorder+0
	sta $d04a
	lda #%00001111
	trb $d04b
	lda BotBorder+1
	tsb $d04b

	// TEXTYPOS - CharYStart
	lda TextYPos+0
	sta $d04e
	lda #%00001111
	trb $d04f
	lda TextYPos+1
	tsb $d04f

	//_add16im(BotBorder, 2, IRQBotPos)
	_add16im(verticalCenter, (MAX_HEIGHT)+4, IRQBotPos)

	lsr IRQBotPos+1
	ror IRQBotPos+0

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

}

// ------------------------------------------------------------
