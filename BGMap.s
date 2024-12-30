// ------------------------------------------------------------
//
.segment Code "BGMap"

BgMap1:
.dword 	BGMap0TileRAM       // 32bit pointer to decompressed tile ram
.dword 	BGMap0AttribRAM     // 32bit pointer to decompressed attrib ram
.word 	BGROWSIZE           // 16bit size of bytes per line
.word	$0040               // 16bit number of 8 pixel height chars to wrap on

BgMap2:
.dword 	BGMap1TileRAM       // 32bit pointer to decompressed tile ram
.dword 	BGMap1AttribRAM     // 32bit pointer to decompressed attrib ram
.word 	BGROWSIZE           // 16bit size of bytes per line
.word	$0040               // 16bit number of 8 pixel height chars to wrap on

// ------------------------------------------------------------
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
    _set16im(Bg0Map, map_base)

    _set32im(BGMap0TileRAM, chr_ptr)		// map is decompressed to this location
    _set32im(BGMap0AttribRAM, attrib_ptr)

	_set8im((PAL_BG0<<4) | $0f, palIndx)

    jsr InitMap

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
	_set16im(Bg1Tiles, tile_map)
	_set16im((bg1Chars.addr/64), chr_offs)
    _set16im(Bg1Map, map_base)

    _set32im(BGMap1TileRAM, chr_ptr)		// map is decompressed to this location
    _set32im(BGMap1AttribRAM, attrib_ptr)

	_set8im((PAL_BG1<<4) | $0f, palIndx)

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
.segment Data "BgMap Buffer"
Bg0Map:
	.import binary "./sdcard/bg2_LV0L0_map.bin"
Bg1Map:
	.import binary "./sdcard/bg2_LV1L0_map.bin"

.segment Data "Bg0 Tiles"
Bg0Tiles:
	.import binary "./sdcard/bg20_tiles.bin"
Bg1Tiles:
	.import binary "./sdcard/bg21_tiles.bin"

// ------------------------------------------------------------
//
.segment MapRam "Map RAM 0"
BGMap0TileRAM:
	.fill (BGROWSIZE*BGNUMROWS), $00
BGMap0AttribRAM:
	.fill (BGROWSIZE*BGNUMROWS), $00

.segment MapRam "Map RAM 1"
BGMap1TileRAM:
	.fill (BGROWSIZE*BGNUMROWS), $00
BGMap1AttribRAM:
	.fill (BGROWSIZE*BGNUMROWS), $00

