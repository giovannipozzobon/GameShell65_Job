// ------------------------------------------------------------

.var 	LOGICAL_ROW_SIZE = 0
.var	FIRST_LAYER = true

.enum {ChrLayer, RRBLayer, EOLLayer}
.struct Layer { id, name, palIdx, num, firstLayer, layerType, GotoXOffs, ChrOffs, ChrSize, DataSize, isNCM }

.var LayerList = List()

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

	.print "adding layer " + name + " at offs " + LOGICAL_ROW_SIZE
	
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

	.print "end of line " + name + " at offs " + LOGICAL_ROW_SIZE
	
	.eval LOGICAL_ROW_SIZE += dataSize

	.print "LOGICAL_ROW_SIZE = " + LOGICAL_ROW_SIZE

	.return LayerList.get(id)
}

.function Layer_RRB (name, numWords, palIdx) {
	//id, name, address, spriteSet, startFrame, endFrame 
	.var id = LayerList.size()
	.var dataSize = numWords * 2	 		// numWords [16bit chars]

	.eval LayerList.add(Layer(
		id,
		name,
		palIdx,
		numWords,
		FIRST_LAYER,
		RRBLayer,
		LOGICAL_ROW_SIZE,
		LOGICAL_ROW_SIZE + 2,
		dataSize,
		dataSize,
		false
	))

	.print "adding layer " + name + " at offs " + LOGICAL_ROW_SIZE
	
	.eval LOGICAL_ROW_SIZE += dataSize

	.return LayerList.get(id)
}

// ------------------------------------------------------------
