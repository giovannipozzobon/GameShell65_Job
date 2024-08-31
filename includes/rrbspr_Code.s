.enum {RRBSpr16x8, RRBSpr16x16, RRBSpr32x16, RRBSpr32x32}

.namespace RRBSpr
{

// ------------------------------------------------------------
//
.segment Zeropage "RRBSpr"
XPos:		.word $0000
YPos:		.word $0000
BaseChr:	.word $0000
SChr:		.byte $00
Pal:		.byte $00

// ------------------------------------------------------------
//
.segment Code "RRBSpr"

Clear: {
	.var chr_ptr = Tmp
	.var attrib_ptr = Tmp1

	// Clear the RRBIndex list
	_set32im(RRBTileBuffer, chr_ptr)
	_set32im(RRBAttribBuffer, attrib_ptr)

	ldx #0
!:		
	// Set the RRB count with the number of bytes available on this row
	lda #LayerRRB.DataSize
	sta RRBCount,x

	// Set the RRB ptr to the beginning of RRB data for this row
	lda chr_ptr+0
	sta RRBTileRowTableLo,x
	lda chr_ptr+1
	sta RRBTileRowTableHi,x

	lda attrib_ptr+0
	sta RRBAttribRowTableLo,x
	lda attrib_ptr+1
	sta RRBAttribRowTableHi,x

	// Advance to the next row
	_add16im(chr_ptr, LayerRRB.DataSize, chr_ptr)
	_add16im(attrib_ptr, LayerRRB.DataSize, attrib_ptr)

	inx
	cpx #NUM_ROWS
	bne !-

	// Clear the RRB characters using DMA
	RunDMAJob(Job)

	rts 
Job:
	DMAHeader($00, RRBTileBuffer>>20)
	.for(var r=0; r<NUM_ROWS; r++) {
		// Tile
		DMACopyJob(
			RRBTileClear, 
			RRBTileBuffer + (r * LayerRRB.DataSize),
			LayerRRB.DataSize,
			true, false)
		// Atrib
		DMACopyJob(
			RRBAttribClear,
			RRBAttribBuffer + (r * LayerRRB.DataSize),
			LayerRRB.DataSize,
			(r!=(NUM_ROWS-1)), false)
	}
	.print("RRBClear DMAjob = " + (* - Job))
}	

//
// Params:	A = sprite meta
//
Draw: {
	.var x_pos = Tmp
	.var chr_ptr = Tmp1			// 32bit
	.var attrib_ptr = Tmp2		// 32bit
	.var bytesAdded = Tmp3		// 8bit
	.var charToDraw = Tmp3+1	// 8bit

	// Store A which is the sprMeta index for later
	sta sprMeta

	phy
	phz

	sec
	lda XPos+0
	sbc #$e0
	sta bcheck0
	lda XPos+1
	sbc #$ff
	sta bcheck1
	lbmi !Exit+

	lda bcheck0:#$00
	cmp #<(SCREEN_WIDTH + $20)
	lda bcheck1:#$00
	sbc #>(SCREEN_WIDTH + $20)
	lbcs !Exit+

	// Restore the sprMeta index
	ldy sprMeta:#$00

	lda SprMetaRows,y
	sta rowsToDraw
	lda SprMetaBytes,y
	sta bytesAdded
	lda SprMetaStride,y
	sta rowStride

	// We are going to render this sprite, setup 32bit tile and attrib ptrs
	_set32im(RRBTileBuffer, chr_ptr)
	_set32im(RRBAttribBuffer, attrib_ptr)

	//Set ypos fine
	lda YPos
	and #$07
	eor #$07
	asl 
	asl 
	asl 
	asl 
	asl
	sta ypos

	ldz SChr
	stz charToDraw

	lda YPos
	lsr 
	lsr 
	lsr 
	tax 

	ldy rowsToDraw:#$02
!loop:
	//grab row from ypos coarse
	cpx #[NUM_ROWS]
	lbcs !Exit+

	lda RRBCount,x
	cmp bytesAdded
	lbcc !Skip+

	clc
	lda BaseChr+0
	adc charToDraw
	sta icharToDrawL
	lda BaseChr+1
	adc #$00
	sta icharToDrawH

	// Update the 16bit portions of tile and attrib ptrs
	lda RRBTileRowTableLo,x
	sta chr_ptr+0
	lda RRBTileRowTableHi,x
	sta chr_ptr+1
	lda RRBAttribRowTableLo,x
	sta attrib_ptr+0
	lda RRBAttribRowTableHi,x
	sta attrib_ptr+1

	//Position X sprite
	ldz #0

	lda XPos + 0
	sta ((chr_ptr)),z
	lda #$94
	sta ((attrib_ptr)),z
	inz
	lda XPos + 1
	and #$03
	ora ypos:#$ff
	sta ((chr_ptr)),z
	lda #$00
	sta ((attrib_ptr)),z
	inz

!cloop:

	//Draw sprite
	lda icharToDrawL:#$07
	sta ((chr_ptr)),z
	lda #$08
	sta ((attrib_ptr)),z
	inz
	lda icharToDrawH:#$00
	sta ((chr_ptr)),z
	lda Pal
	sta ((attrib_ptr)),z
	inz

	clc
	lda icharToDrawL
	adc rowStride:#$05
	sta icharToDrawL
	lda icharToDrawH
	adc #$00
	sta icharToDrawH

	cpz bytesAdded
	bne !cloop-

	// Reduce the number of bytes available by the bytes added this on this row
	sec
	lda RRBCount,x
	sbc bytesAdded
	sta RRBCount,x

	clc
	lda RRBTileRowTableLo,x
	adc bytesAdded
	sta RRBTileRowTableLo,x
	lda RRBTileRowTableHi,x
	adc #0
	sta RRBTileRowTableHi,x

	clc
	lda RRBAttribRowTableLo,x
	adc bytesAdded
	sta RRBAttribRowTableLo,x
	lda RRBAttribRowTableHi,x
	adc #0
	sta RRBAttribRowTableHi,x

!Skip:		
	inc charToDraw
	inx 

	dey
	lbne !loop-

!Exit:

	plz
	ply
	rts
}

.segment Data "RRBSpr"
				//    16x8,	16x16,	32x16,	32x32
SprMetaRows: 	.byte $02,	$03, 	$03,	$05
SprMetaBytes:	.byte $04, 	$04, 	$06,	$06
SprMetaStride:	.byte $00, 	$00, 	$03,	$05

}
