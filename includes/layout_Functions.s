// ------------------------------------------------------------
// 
.struct Layout { id, name, begin, end, pixieId, logicalSize }

.var LayoutList = List()

// ------------------------------------------------------------
//

.function NewLayout (name) 
{
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

.function EndLayout (layout) 
{
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
