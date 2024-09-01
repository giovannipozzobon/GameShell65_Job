//--------------------------------------------------------
// Layers
//--------------------------------------------------------
.namespace Layers
{

//--------------------------------------------------------
//
.segment Zeropage "Layer ZP"

//--------------------------------------------------------
//
.segment Code "Layer Code"

// -------------------------------------------------------
// X = Layer Id
// A = Layer position Lo
SetXPosLo:
{
	sta ScrollXLo,x
	lda #$01
	sta ScrollUpdate,x
	rts
}

// -------------------------------------------------------
// X = Layer Id
// A = Layer position Hi
SetXPosHi:
{
	sta ScrollXHi,x
	lda #$01
	sta ScrollUpdate,x
	rts
}

// ------------------------------------------------------------
// X = Layer Id
// A = Fine scroll value
SetFineScroll: 
{
	and #$0f
	sta ul2xscroll
	sec
	lda #0
	sbc ul2xscroll:#$00
	sta ScrollXLo,x
	lda #0
	sbc #0
	and #$03
	sta ScrollXHi,x

	lda #$01
	sta ScrollUpdate,x

	rts
}

// ------------------------------------------------------------
//
UpdateScrollPositions: 
{
	.var tile_ptr = Tmp			// 32bit
	.var attrib_ptr = Tmp1		// 32bit
	.var gotoOffs = Tmp2		// 16bit

	ldx #0

!layerloop:
	lda Layers.ScrollUpdate,x
	lbeq !layerskip+

	lda #$00
	sta Layers.ScrollUpdate,x

	// setup the scroll position
	lda Layers.ScrollXLo,x
	sta xposLo
	lda Layers.ScrollXHi,x
	and #$03
	sta xposHi

	lda Layers.Trans,x
	sta transFlag

	// setup the gotox offset
	lda Layers.LogOffsLo,x
	sta gotoOffs+0
	lda Layers.LogOffsHi,x
	sta gotoOffs+1

    _set32im(SCREEN_RAM, tile_ptr)
    _add16(tile_ptr, gotoOffs, tile_ptr)
    _set32im(COLOR_RAM, attrib_ptr)
    _add16(attrib_ptr, gotoOffs, attrib_ptr)

	phx

		ldy #NUM_ROWS
!loop:
		// Set GotoX position
		ldz #0
		lda xposLo:#$00
		sta ((tile_ptr)), z
		lda transFlag:#$10
		sta ((attrib_ptr)),z
		inz
		lda xposHi:#$00
		sta ((tile_ptr)), z
		lda #$00
		sta ((attrib_ptr)),z

	    _add16im(tile_ptr, LOGICAL_ROW_SIZE, tile_ptr)
	    _add16im(attrib_ptr, LOGICAL_ROW_SIZE, attrib_ptr)

		dey
		lbne !loop-

	plx

!layerskip:

	inx
	cpx #LayerList.size()
	lbne !layerloop-

	rts
}

UpdateData: {
	.var src_tile_ptr = Tmp			// 32bit
	.var src_attrib_ptr = Tmp1		// 32bit

	.var dst_offset = Tmp2			// 16bit
	.var copy_length = Tmp2+2		// 16bit

	.var src_offset = Tmp3			// 16bit
	.var src_stride = Tmp3+2		// 16bit

	.var full_size = Tmp4			// 16bit
	.var src_and = Tmp4+2			// 16bit

	UpdateLayer1: {
		_set32im(BGMap1TileRAM, src_tile_ptr)
		_set32im(BGMap1AttribRAM, src_attrib_ptr)

		_set16im(Layer1.ChrOffs, dst_offset)
		_set16im(Layer1.ChrSize, full_size)

		_set16im(BGROWSIZE, src_stride)

		_set16(Camera.XScroll1, src_offset)

		_set16im($003e, src_and)
		_set16im($0040, copy_length)

		jsr CopyScrollingLayerChunks

		rts
	}

	UpdateRRB: {
		_set32im(RRBTileBuffer, src_tile_ptr)
		_set32im(RRBAttribBuffer, src_attrib_ptr)

		_set16im(LayerRRB.GotoXOffs, dst_offset)
		_set16im(LayerRRB.DataSize, copy_length)

		_set16im(0, src_offset)
		_set16im(LayerRRB.DataSize, src_stride)

		jsr CopyLayerChunks

		rts
	}

	InitEOL: {
		.var dst_tile_ptr = Tmp			// 32bit
		.var dst_attrib_ptr = Tmp1		// 32bit

		_set32im(SCREEN_RAM + LayerEOL.ChrOffs, dst_tile_ptr)
		_set32im(COLOR_RAM + LayerEOL.ChrOffs, dst_attrib_ptr)

		ldy #$00
	!:
		ldz #$00
		lda #$00
		sta ((dst_tile_ptr)),z
		lda #$00
		sta ((dst_attrib_ptr)),z
		inz
		lda #$00
		sta ((dst_tile_ptr)),z
		lda #$00
		sta ((dst_attrib_ptr)),z

		_add16im(dst_tile_ptr, LOGICAL_ROW_SIZE, dst_tile_ptr)
		_add16im(dst_attrib_ptr, LOGICAL_ROW_SIZE, dst_attrib_ptr)

		iny
		cpy #NUM_ROWS
		bne !-

		rts
	}

	CopyScrollingLayerChunks: {
		lsr src_offset+1
		ror src_offset+0
		lsr src_offset+1
		ror src_offset+0
		lsr src_offset+1
		ror src_offset+0

		_and16(src_offset, src_and, src_offset)
		_sub16(copy_length, src_offset, copy_length)

		lda full_size+0
		cmp copy_length+0
		lda full_size+1
		sbc copy_length+1
		bcs !ee+
		_set16(full_size, copy_length)
!ee:

		jsr CopyLayerChunks

		// need to fix this with >255 byte wide maps?
		lda full_size+0
		cmp copy_length+0
		bne !next+
		lda full_size+1
		cmp copy_length+1
		beq !done+

!next:
		_add16(dst_offset, copy_length, dst_offset)
		_set16im(0, src_offset)

		_sub16(full_size, copy_length, copy_length)

		jsr CopyLayerChunks

!done:
		rts
	}

	CopyLayerChunks: {
		_set16(copy_length, tileLength)
		_set16(copy_length, attribLength)

		// Tiles are copied from Bank 0 to (SCREEN_RAM>>20)
		lda #$00
		sta tileSourceBank
		lda #SCREEN_RAM>>20
		sta tileDestBank

		// Attribs are copied from Bank 0 to (COLOR_RAM>>20)
		lda #$00
		sta attribSourceBank
		lda #COLOR_RAM>>20
		sta attribDestBank

		// DMA tile rows
		//
		clc
		lda src_tile_ptr+0
		adc src_offset+0
		sta tileSource+0
		lda src_tile_ptr+1
		adc src_offset+1
		sta tileSource+1
		lda src_tile_ptr+2
		sta tileSource+2

		clc
		lda #<SCREEN_RAM
		adc dst_offset+0
		sta tileDest+0
		lda #>SCREEN_RAM
		adc dst_offset+1
		sta tileDest+1
		lda #[SCREEN_RAM >> 16]
		and #$0f
		sta tileDest+2

		ldx #$00
	!tloop:
		RunDMAJob(TileJob)

		_add16(tileSource, src_stride, tileSource)
		_add16im(tileDest, LOGICAL_ROW_SIZE, tileDest)

		inx
		cpx #NUM_ROWS
		bne !tloop-

		// DMA attribute rows
		//
		clc
		lda src_attrib_ptr+0
		adc src_offset+0
		sta attribSource+0
		lda src_attrib_ptr+1
		adc src_offset+1
		sta attribSource+1
		lda src_attrib_ptr+2
		sta attribSource+2

		clc
		lda #<COLOR_RAM
		adc dst_offset+0
		sta attribDest+0
		lda #>COLOR_RAM
		adc dst_offset+1
		sta attribDest+1
		lda #[COLOR_RAM >> 16]
		and #$0f
		sta attribDest+2

		ldx #$00
	!aloop:
		RunDMAJob(AttribJob)

		_add16(attribSource, src_stride, attribSource)
		_add16im(attribDest, LOGICAL_ROW_SIZE, attribDest)

		inx
		cpx #NUM_ROWS
		bne !aloop-

		rts 

	TileJob:
		.byte $0A 						// Request format is F018A
		.byte $80
	tileSourceBank:
		.byte $00						// Source BANK
		.byte $81
	tileDestBank:
		.byte $00						// Dest BANK

		.byte $00 						// No more options
		.byte $00 						// Copy and last request
	tileLength:
		.word $0000						// Size of Copy

		//byte 04
	tileSource:	
		.byte $00,$00,$00				// Source

		//byte 07
	tileDest:
		.byte $00,$00,$00				// Destination & $ffff, [[Destination >> 16] & $0f]

	AttribJob:
		.byte $0A 						// Request format is F018A
		.byte $80
	attribSourceBank:
		.byte $00						// Source BANK
		.byte $81
	attribDestBank:
		.byte $00						// Dest BANK

		.byte $00 						// No more options
		.byte $00 						// Copy and last request
	attribLength:
		.word $0000						// Size of Copy

		//byte 04
	attribSource:	
		.byte $00,$00,$00				// Source

		//byte 07
	attribDest:
		.byte $00,$00,$00				// Destination & $ffff, [[Destination >> 16] & $0f]
	}
}

.segment Data "Layer Data"
Trans:
	.fill LayerList.size(), LayerList.get(i).firstLayer ? $10|$04 : $90|$04
LogOffsLo:
	.fill LayerList.size(), <LayerList.get(i).GotoXOffs
LogOffsHi:
	.fill LayerList.size(), >LayerList.get(i).GotoXOffs

.segment Data "Layer Tables"
LayerRowOffsLo:
	.fill NUM_ROWS, <[(i * LOGICAL_ROW_SIZE)]
LayerRowOffsHi:
	.fill NUM_ROWS, >[(i * LOGICAL_ROW_SIZE)]

.segment BSS "Layer BSS"
ScrollUpdate:
	.fill LayerList.size(), $00

ScrollXLo:
	.fill LayerList.size(), $40
ScrollXHi:
	.fill LayerList.size(), $01

}
