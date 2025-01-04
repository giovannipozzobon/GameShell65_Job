// ------------------------------------------------------------
// 
.var MAX_NUM_ROWS = 0
.var MAX_HEIGHT = 0

.struct Layout { id, name, width, height, begin, end, pixieId, logicalSize, numRows }

.var LayoutList = List()

// ------------------------------------------------------------
//

.function NewLayout (name, width, height, numRows) 
{
	.var id = LayoutList.size()

	.print "Layout [" + name + "] id = " + id

	.eval LayoutList.add(Layout(
		id,
		name,
		width,
		height,
		LayerList.size(),
		0,
		0,
		0,
		numRows
	))

	.if (numRows > MAX_NUM_ROWS)
	{
		.eval MAX_NUM_ROWS = numRows
	}

	.if (height > MAX_HEIGHT)
	{
		.eval MAX_HEIGHT = height
	}

	// Reset layer tracking vars
	.eval LOGICAL_ROW_SIZE = 0
	.eval FIRST_LAYER = true
	.eval PIXIE_LAYER = 0

	.return LayoutList.get(id)
}

.function EndLayout (layout) 
{
	.if ((layout.numRows * LOGICAL_ROW_SIZE) > MAX_SCREEN_SIZE)
	{
		.eval MAX_SCREEN_SIZE = (layout.numRows * LOGICAL_ROW_SIZE)
	}

	.eval layout.pixieId = PIXIE_LAYER
	.eval layout.logicalSize = LOGICAL_ROW_SIZE
	.eval layout.end = LayerList.size()

	.print "Layout [" + layout.name + "] numLayers = " + (layout.end - layout.begin) + " | logicalSize = " + layout.logicalSize
}

// ------------------------------------------------------------
