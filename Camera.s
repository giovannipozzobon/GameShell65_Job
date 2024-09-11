.namespace Camera
{

// ------------------------------------------------------------
//
.segment BSS "Camera"
XScroll:		.byte $00,$00
YScroll:		.byte $00,$00

XScroll1:		.byte $00,$00
YScroll1:		.byte $00,$00

// ------------------------------------------------------------
//
.segment Code "Camera"
Init: {
	_set16im(0, XScroll)
	_set16im(0, YScroll)
	_set16im(0, XScroll1)
	_set16im(0, YScroll1)

	rts
}

CalcParallax: {
	_set16(XScroll, XScroll1)
	_set16(YScroll, YScroll1)

	rts
}

// ------------------------------------------------------------

}