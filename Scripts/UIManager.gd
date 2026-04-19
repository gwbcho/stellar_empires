extends CanvasLayer
class_name UIManager

@onready var tooltip_label: Label = $TooltipLabel
var following_mouse: bool = false

func _ready():
	tooltip_label.hide()

func _process(_delta):
	if following_mouse:
		# Attach the tooltip directly to the cursor with an offset
		tooltip_label.position = tooltip_label.get_global_mouse_position() + Vector2(15, -25)

func show_tooltip(text: String):
	tooltip_label.text = text
	tooltip_label.show()
	following_mouse = true

func hide_tooltip():
	tooltip_label.hide()
	following_mouse = false
