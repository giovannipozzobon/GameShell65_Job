.const SDFILENAME = $0200 //-$03ff
.const HVC_SD_TO_CHIPRAM = $36
.const HVC_SD_TO_ATTICRAM = $3e

.pseudocommand SDCard_LoadToChipRam addr : filePtr {
	M65_SaveRegisters()
		lda #>filePtr.getValue()
		ldx #<filePtr.getValue()
		jsr SDIO.CopyFileName

		ldx #<addr.getValue()
		ldy #>addr.getValue()
		ldz #[[addr.getValue() & $ff0000] >> 16]

		jsr SDIO.LoadChip
	M65_RestoreRegisters()
}

SDIO: {
	CopyFileName: {
		sta FileName + 1
		stx FileName + 0

		ldx #$00
	!:
		lda FileName:$BEEF, x 
		sta SDFILENAME, x 
		inx
		bne !-

		ldx #<SDFILENAME
		ldy #>SDFILENAME
		lda #$2e	
		sta $d640 
		nop
		bcs !success+
		lda #$04
		jmp SDIO.Error
	!success:
		rts
	}
	LoadAttic: {
		lda #HVC_SD_TO_ATTICRAM
		sta $d640 
		nop
		bcs !success+
		lda #$02
		jmp SDIO.Error
	!success:		
		rts		
	}
	LoadChip: {
		lda #HVC_SD_TO_CHIPRAM
		sta $d640 
		nop
		bcs !success+
		lda #$03
		jmp SDIO.Error
	!success:
		rts		
	}

	Error: {
		sta $d020  
		lda #$38
		sta $d640
		clv 
		tax
	!:
		lda $d020
		clc 
		adc #$01
		and #$0f 
		sta $d020
		jmp !-
	}

}
