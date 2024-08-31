.namespace Camera
{

// ------------------------------------------------------------
//
.segment BSS "Camera"
XScroll:		.byte $00,$00

XScroll1:		.byte $00,$00

// ------------------------------------------------------------
//
.segment Code "Camera"
Init: {
	lda #$00
	sta XScroll+0
	sta XScroll+1

	sta XScroll1+0
	sta XScroll1+1

	rts
}

CalcParallax: {
	lda XScroll+0
	sta XScroll1+0
	lda XScroll+1
	sta XScroll1+1

	rts
}

// ------------------------------------------------------------

}