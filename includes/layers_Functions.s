// ------------------------------------------------------------
// 
.var 	LOGICAL_ROW_SIZE = 0
.var	MAX_SCREEN_SIZE = 0			// max number of bytes a layout will take in screen ram

.var	FIRST_LAYER = true

.var 	PIXIE_LAYER = 0

.enum {ChrLayer, PixieLayer, EOLLayer}
.struct Layer { id, name, palIdx, num, firstLayer, layerType, GotoXOffs, ChrOffs, ChrSize, DataSize, isNCM }

.struct Layout { id, name, begin, end, pixieId, logicalSize }

.var LayerList = List()

.var LayoutList = List()

// ------------------------------------------------------------
//

.function NewLayout (name) {
	.var id = LayoutList.size()

	.print "Layout [" + name + "] id = " + id

	.eval LayoutList.add(Layout(
		id,
		name,
		LayerList.size(),
		0,
		0,
		0
	))

	// Reset layer tracking vars
	.eval LOGICAL_ROW_SIZE = 0
	.eval FIRST_LAYER = true
	.eval PIXIE_LAYER = 0

	.return LayoutList.get(id)
}

.function EndLayout (layout) {
	.if ((NUM_ROWS * LOGICAL_ROW_SIZE) > MAX_SCREEN_SIZE)
	{
		.eval MAX_SCREEN_SIZE = (NUM_ROWS * LOGICAL_ROW_SIZE)
	}

	.eval layout.pixieId = PIXIE_LAYER
	.eval layout.logicalSize = LOGICAL_ROW_SIZE
	.eval layout.end = LayerList.size()

	.print "Layout [" + layout.name + "] numLayers = " + (layout.end - layout.begin) + " | logicalSize = " + layout.logicalSize
}

// ------------------------------------------------------------
//

.function Layer_BG (name, numChars, isNCM, palIdx) {
	//id, name, address, spriteSet, startFrame, endFrame 
	.var id = LayerList.size()
	.var chrSize = (numChars) * 2			// numChars [16bit chars]
	.var dataSize = chrSize + 2		 		// gotox + chrSize

	.eval LayerList.add(Layer(
		id,
		name,
		palIdx,
		numChars,
		FIRST_LAYER,
		ChrLayer,
		LOGICAL_ROW_SIZE,
		LOGICAL_ROW_SIZE + 2,
		chrSize,
		dataSize,
		isNCM
	))

	.print "    adding layer " + name + " at offs " + LOGICAL_ROW_SIZE
	
	.eval LOGICAL_ROW_SIZE += dataSize
	.eval FIRST_LAYER = false

	.return LayerList.get(id)
}

.function Layer_EOL (name) {
	//id, name, address, spriteSet, startFrame, endFrame 
	.var id = LayerList.size()
	.var numChars = 1
	.var chrSize = (numChars) * 2				// numChars [16bit chars]
	.var dataSize = chrSize + 2			// gotox + chrSize

	.eval LayerList.add(Layer(
		id,
		name,
		0,
		numChars,
		FIRST_LAYER,
		EOLLayer,
		LOGICAL_ROW_SIZE,
		LOGICAL_ROW_SIZE+2,
		chrSize,
		dataSize,
		false
	))

	.print "    end of line " + name + " at offs " + LOGICAL_ROW_SIZE
	
	.eval LOGICAL_ROW_SIZE += dataSize

	.return LayerList.get(id)
}

.function Layer_PIXIE (name, numWords, palIdx) {
	//id, name, address, spriteSet, startFrame, endFrame 
	.var id = LayerList.size()
	.var dataSize = numWords * 2	 		// numWords [16bit chars]

	.eval LayerList.add(Layer(
		id,
		name,
		palIdx,
		numWords,
		FIRST_LAYER,
		PixieLayer,
		LOGICAL_ROW_SIZE,
		LOGICAL_ROW_SIZE + 2,
		dataSize,
		dataSize,
		false
	))

	.print "    adding layer " + name + " at offs " + LOGICAL_ROW_SIZE
	
	.eval PIXIE_LAYER = id;

	.eval LOGICAL_ROW_SIZE += dataSize

	.return LayerList.get(id)
}

// ------------------------------------------------------------
