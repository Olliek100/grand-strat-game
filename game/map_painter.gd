class_name MapPainter
extends Node2D

# A drawing surface for one layer of the map. The map view owns the drawing code and hands each
# layer a callable, so layers can sit at different depths (and inside or outside the camera).

var paint: Callable

func _draw():
	if paint.is_valid():
		paint.call(self)
