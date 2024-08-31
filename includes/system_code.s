//--------------------------------------------------------
// System
//--------------------------------------------------------
.namespace System
{

//--------------------------------------------------------
//
.segment Zeropage "System ZP"
TopBorder:		.word $0000
BotBorder:		.word $0000
IRQTopPos:		.word $0000
IRQBotPos:		.word $0000
SprYBase:		.byte $00

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

	lda #<$0a00			// set offset to colour ram so we can use the first 8kb for something else and $10000-$60000 is a continuous playground without the colour ram in the middle
	sta $d064			// this causes a 1 pixel bug in the bottom right of the screen, so commenting it out again for now.
	lda #>$0a00
	sta $d065

	rts
}

DisableScreen:
{
	lda #$00
	sta $d011
	rts
}

EnableScreen:
{
	lda #$1b
	sta $d011
	lda #%00000101		//Set bit2=FCM for chars >$ff,  bit0=16 bit char indices
	tsb $d054
	rts
}

CenterFrameHorizontally:
{
	.var charXPos = Tmp				// 16bit

	_set16im(LEFT_BORDER, charXPos)

	// SDBDRWDLSB,SDBDRWDMSB - Side Border size
	lda charXPos+0
	sta $d05c
	lda #%00111111
	trb $d05d
	lda charXPos+1
	and #%00111111
	tsb $d05d

	// TEXTXPOS - Text X Pos

	// If running on real hardware, shift screen left SCALED pixel
	lda $d60f
	and #%00100000
	beq !+
	_sub16im(charXPos, HPIXELSCALE, charXPos)
!:

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
	.var charYPos = Tmp1				// 16bit

	// The half height of the screen in rasterlines is (charHeight / 2) * 2
	_set16im(NUM_ROWS * 8, halfCharHeight)

	// Figure out the vertical center of the screen

	// PAL values
	_set16im(304, verticalCenter)
	_set8im($fe, SprYBase)

	bit $d06f
	bpl isPal

	// NTSC values
	_set16im(242, verticalCenter)
	_set8im($16, SprYBase)

isPal:

	_sub16(verticalCenter, halfCharHeight, TopBorder)
	_add16(verticalCenter, halfCharHeight, BotBorder)

	_set16(TopBorder, charYPos)

	// hack!!
	// If we are running on real hardware then adjust char Y start up to avoid 2 pixel Y=0 bug
	lda $d60f
	and #%00100000
	beq !+

	_add16im(TopBorder, 1, TopBorder)
	_add16im(BotBorder, 1, BotBorder)
	_sub16im(charYPos, 2, charYPos)

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
	lda charYPos+0
	sta $d04e
	lda #%00001111
	trb $d04f
	lda charYPos+1
	tsb $d04f

	_add16im(TopBorder, 1, IRQTopPos)

	lsr IRQTopPos+1
	ror IRQTopPos+0

	_add16im(BotBorder, 1, IRQBotPos)

	lsr IRQBotPos+1
	ror IRQBotPos+0

	clc
	lda SprYBase
	adc IRQTopPos+0
	sta SprYBase

	rts
}

}

// ------------------------------------------------------------