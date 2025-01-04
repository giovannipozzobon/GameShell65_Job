// ------------------------------------------------------------
//
.segment Zeropage "Pixie ZP"

DrawPosX:		.byte $00,$00
DrawPosY:		.byte $00,$00
DrawBaseChr:    .byte $00,$00
DrawPal:        .byte $00
DrawSChr:		.byte $00

PixieYShift:	.byte $00

// ------------------------------------------------------------
//
.segment Code "Pixie Code"

// ------------------------------------------------------------
//
ClearWorkPixies: {
	.var rowScreenPtr = Tmp		// 16bit
	.var rowAttribPtr = Tmp+2	// 16bit

	lda #$00
	sta PixieYShift
	
	_set16im(PixieWorkTiles, rowScreenPtr)
	_set16im(PixieWorkAttrib, rowAttribPtr)

	// Clear the RRBIndex list
	ldx #0
!:
	lda #NUM_PIXIES
	sta PixieUseCount,x

	lda rowScreenPtr+0
	sta PixieRowScreenPtrLo,x
	lda rowScreenPtr+1
	sta PixieRowScreenPtrHi,x

	lda rowAttribPtr+0
	sta PixieRowAttribPtrLo,x
	lda rowAttribPtr+1
	sta PixieRowAttribPtrHi,x

	_add16im(rowScreenPtr, Layout1_Pixie.DataSize, rowScreenPtr)
	_add16im(rowAttribPtr, Layout1_Pixie.DataSize, rowAttribPtr)
	
	inx
	cpx Layout.NumRows
	bne !-

	// Clear the working pixie data using DMA
	RunDMAJob(Job)

	rts 
Job:
	DMAHeader(ClearPixieTile>>20, PixieWorkTiles>>20)
	.for(var r=0; r<MAX_NUM_ROWS; r++) {
		// Tile
		DMACopyJob(
			ClearPixieTile, 
			PixieWorkTiles + (r * Layout1_Pixie.DataSize),
			Layout1_Pixie.DataSize,
			true, false)
		// Atrib
		DMACopyJob(
			ClearPixieAttrib,
			PixieWorkAttrib + (r * Layout1_Pixie.DataSize),
			Layout1_Pixie.DataSize,
			(r!=(MAX_NUM_ROWS-1)), false)
	}
}	

// ------------------------------------------------------------
//
yShiftTable:	.byte (0<<5)|$10,(1<<5)|$10,(2<<5)|$10,(3<<5)|$10,(4<<5)|$10,(5<<5)|$10,(6<<5)|$10,(7<<5)|$10
yMaskTable:		.byte %11111111,%11111110,%11111100,%11111000,%11110000,%11100000,%11000000,%10000000

DrawPixie:
{
	.var tilePtr = Tmp					// 32bit
	.var attribPtr = Tmp1				// 32bit

	.var charIndx = Tmp2+0				// 16bit
	.var yShift = Tmp2+2				// 8bit
	.var gotoXmask = Tmp2+3				// 8bit

	phx
	phy
	phz

	_set16(DrawBaseChr, charIndx)		// Start charIndx with first pixie char

	_set32im(PixieWorkTiles, tilePtr)	// Set base full 32 bit pointers
	_set32im(PixieWorkAttrib, attribPtr)

	clc
	lda charIndx+0
	adc DrawSChr
	sta charIndx+0
	lda charIndx+1
	adc #$00
	sta charIndx+1

	lda PixieYShift
	and #$07
	sta lshift
	
	lda DrawPosY
	clc
	adc lshift:#$00
	sta DrawPosY

	lda DrawPosY+0						// Find sub row y offset (0 - 7)
	and #$07
	tay	

	lda yMaskTable,y					// grab the rowMask value
	sta gotoXmask

	lda yShiftTable,y					// grab the yShift value 
	sta yShift

	// Calculate which row to add pixie data to, put this in X,
    // we use this to index the row tile / attrib ptrs
 	// 
	lda DrawPosY+0
	lsr
	lsr
	lsr
	dec									// move up 2 rows to add top clipping
	dec
	tax									// move yRow into X reg
	bmi middleRow
	cpx Layout.NumRows
	lbcs done

	// See if number of words has been exhausted
	lda PixieUseCount,x
	beq middleRow
	dec PixieUseCount,x

	// Top character, this uses the first mask from the tables above,
    // grab tile and attrib ptr for this row and advance by the 4 bytes
    // that we will write per row.
	//
	clc                                 // grab and advance tilePtr
	lda PixieRowScreenPtrLo,x
	sta tilePtr+0
	adc #$04
	sta PixieRowScreenPtrLo,x
	lda PixieRowScreenPtrHi,x
	sta tilePtr+1
	adc #$00
	sta PixieRowScreenPtrHi,x
	clc                                 // grab and advance attribPtr
	lda PixieRowAttribPtrLo,x
	sta attribPtr+0
	adc #$04
	sta PixieRowAttribPtrLo,x
	lda PixieRowAttribPtrHi,x
	sta attribPtr+1
	adc #$00
	sta PixieRowAttribPtrHi,x

	// GOTOX
	ldz #$00
	lda DrawPosX+0						// tile = <xpos,>xpos | yShift
	sta ((tilePtr)),z
	lda #$98							// attrib = $98 (transparent+gotox+rowmask), gotoXmask
	sta ((attribPtr)),z
	inz
	lda DrawPosX+1
	and #$03
	ora yShift
	sta ((tilePtr)),z
	lda gotoXmask
	sta ((attribPtr)),z
	inz

	// Char
	lda charIndx+0
	sta ((tilePtr)),z
	lda #$08
	sta ((attribPtr)),z
	inz	
	lda charIndx+1
	sta ((tilePtr)),z
	lda DrawPal
	sta ((attribPtr)),z

middleRow:
	// Advance to next row and charIndx
    inw charIndx
	inx
	bmi bottomRow
	cpx Layout.NumRows
	lbcs done
    
	// See if number of words has been exhausted
	lda PixieUseCount,x
	beq bottomRow
	dec PixieUseCount,x

	// Middle character, yShift is the same as first char but full character is drawn so disable rowmask,
    // grab tile and attrib ptr for this row and advance by the 4 bytes
    // that we will write per row.
	//
	clc                                 // grab and advance tilePtr
	lda PixieRowScreenPtrLo,x
	sta tilePtr+0
	adc #$04
	sta PixieRowScreenPtrLo,x
	lda PixieRowScreenPtrHi,x
	sta tilePtr+1
	adc #$00
	sta PixieRowScreenPtrHi,x
	clc                                 // grab and advance attribPtr
	lda PixieRowAttribPtrLo,x
	sta attribPtr+0
	adc #$04
	sta PixieRowAttribPtrLo,x
	lda PixieRowAttribPtrHi,x
	sta attribPtr+1
	adc #$00
	sta PixieRowAttribPtrHi,x	

	// GOTOX
	ldz #$00
	lda DrawPosX+0						// tile = <xpos,>xpos | yShift
	sta ((tilePtr)),z
	lda #$90							// attrib = $98 (transparent+gotox), $00
	sta ((attribPtr)),z
	inz
	lda DrawPosX+1
	and #$03
	ora yShift
	sta ((tilePtr)),z
	lda #$ff
	sta ((attribPtr)),z
	inz

	// Char
	lda charIndx+0
	sta ((tilePtr)),z
	lda #$08
	sta ((attribPtr)),z
	inz	
	lda charIndx+1
	sta ((tilePtr)),z
	lda DrawPal
	sta ((attribPtr)),z

bottomRow:
	// If we have a yShift of 0 we only need to add to 2 rows, skip the last row!
	//
	lda yShift
	and #$e0
	beq done

	// Advance to next row and charIndx
    inw charIndx
	inx
	bmi done
	cpx Layout.NumRows
	lbcs done

	// See if number of words has been exhausted
	lda PixieUseCount,x
	beq done
	dec PixieUseCount,x

	// Bottom character, yShift is the same as first char but flip the bits of the gotoXmask,
    // grab tile and attrib ptr for this row and advance by the 4 bytes
    // that we will write per row.
	//
	clc                                 // grab and advance tilePtr
	lda PixieRowScreenPtrLo,x
	sta tilePtr+0
	adc #$04
	sta PixieRowScreenPtrLo,x
	lda PixieRowScreenPtrHi,x
	sta tilePtr+1
	adc #$00
	sta PixieRowScreenPtrHi,x
	clc                                 // grab and advance tilePtr
	lda PixieRowAttribPtrLo,x
	sta attribPtr+0
	adc #$04
	sta PixieRowAttribPtrLo,x
	lda PixieRowAttribPtrHi,x
	sta attribPtr+1
	adc #$00
	sta PixieRowAttribPtrHi,x

	lda gotoXmask
	eor #$ff
	sta gotoXmask

	// GOTOX
	ldz #$00
	lda DrawPosX+0						// tile = <xpos,>xpos | yShift	
	sta ((tilePtr)),z
	lda #$98							// attrib = $98 (transparent+gotox+rowmask), gotoXmask
	sta ((attribPtr)),z
	inz
	lda DrawPosX+1
	and #$03
	ora yShift
	sta ((tilePtr)),z
	lda gotoXmask
	sta ((attribPtr)),z
	inz

	// Char
	lda charIndx+0
	sta ((tilePtr)),z
	lda #$08
	sta ((attribPtr)),z
	inz	
	lda charIndx+1
	sta ((tilePtr)),z
	lda DrawPal
	sta ((attribPtr)),z

done:

	plz
	ply
	plx

	rts
}

// ------------------------------------------------------------
//
.segment Data "Pixie Clear Data"
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

// ------------------------------------------------------------
//
.segment BSS "Pixie Work Lists"
PixieRowScreenPtrLo:
	.fill MAX_NUM_ROWS, $00
PixieRowScreenPtrHi:
	.fill MAX_NUM_ROWS, $00

PixieRowAttribPtrLo:
	.fill MAX_NUM_ROWS, $00
PixieRowAttribPtrHi:
	.fill MAX_NUM_ROWS, $00

.segment BSS "Pixie Use Count"
PixieUseCount:
	.fill MAX_NUM_ROWS, $00
