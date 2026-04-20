extends CanvasLayer
class_name UIManager

@onready var tooltip_label: Label = $TooltipLabel
var following_mouse: bool = false

var player_resources: Dictionary = {
	"energy": 1500, "minerals": 500, "goods": 200, 
	"alloys": 150, "exotic": 0, "control": 50, "research": 100
}
var resource_incomes: Dictionary = {
	"energy": 45, "minerals": 15, "goods": 5, 
	"alloys": 3, "exotic": 0, "control": 1, "research": 10
}

var resource_keys = ["energy", "minerals", "goods", "alloys", "exotic", "control", "research"]
var resource_colors = [
	Color(1.0, 0.9, 0.2), # Energy
	Color(1.0, 0.4, 0.3), # Minerals
	Color(0.8, 0.6, 0.3), # Goods
	Color(0.8, 0.4, 0.9), # Alloys
	Color(0.2, 0.8, 1.0), # Exotic
	Color(0.9, 0.8, 0.5), # Control
	Color(0.3, 0.9, 0.5)  # Research
]
var top_bar_labels = {}

func _ready():
	tooltip_label.hide()
	build_top_bar()
	build_bottom_left_menu()

func build_top_bar():
	var top_bar_margin = MarginContainer.new()
	top_bar_margin.add_theme_constant_override("margin_top", 10)
	top_bar_margin.add_theme_constant_override("margin_left", 20)
	top_bar_margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(top_bar_margin)
	
	var pb = StyleBoxFlat.new()
	pb.bg_color = Color(0.05, 0.08, 0.12, 0.85)
	pb.border_color = Color(0.2, 0.4, 0.6, 0.6)
	pb.set_border_width_all(2)
	pb.corner_radius_bottom_left = 6
	pb.corner_radius_bottom_right = 6
	pb.corner_radius_top_left = 6
	pb.corner_radius_top_right = 6
	pb.content_margin_left = 25
	pb.content_margin_right = 25
	pb.content_margin_top = 8
	pb.content_margin_bottom = 8
	
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", pb)
	top_bar_margin.add_child(panel)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 35)
	panel.add_child(hbox)
	
	for i in range(resource_keys.size()):
		var key = resource_keys[i]
		var col = resource_colors[i]
		
		var res_hbox = HBoxContainer.new()
		res_hbox.add_theme_constant_override("separation", 8)
		hbox.add_child(res_hbox)
		
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(28, 28)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var cur_img = Image.new()
		if cur_img.load("res://Resources/icon_" + key + ".png") == OK:
			icon_rect.texture = ImageTexture.create_from_image(cur_img)
		else:
			var ph = PlaceholderTexture2D.new()
			ph.size = Vector2(28, 28)
			icon_rect.texture = ph
			
		res_hbox.add_child(icon_rect)
		
		var val_label = Label.new()
		val_label.add_theme_font_size_override("font_size", 18)
		val_label.add_theme_color_override("font_color", col)
		val_label.text = str(player_resources[key])
		res_hbox.add_child(val_label)
		
		var inc_label = Label.new()
		inc_label.add_theme_font_size_override("font_size", 15)
		var inc_val = resource_incomes[key]
		if inc_val > 0:
			inc_label.text = "+" + str(inc_val)
			inc_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4))
		elif inc_val < 0:
			inc_label.text = str(inc_val)
			inc_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		else:
			inc_label.text = "0"
			inc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			
		res_hbox.add_child(inc_label)
		top_bar_labels[key] = {"val": val_label, "inc": inc_label}

func build_bottom_left_menu():
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_theme_constant_override("margin_left", 20)
	margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	margin.grow_horizontal = Control.GROW_DIRECTION_END
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	margin.add_child(hbox)
	
	# Dynamically iterate and inject exact decoupled asset filenames mapped into clean interactive UI nodes!
	var unit_classes = ["colony", "construction", "science", "military"]
	for c in unit_classes:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(64, 64)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.08, 0.12, 0.85)
		style.border_color = Color(0.2, 0.4, 0.6, 0.6)
		style.set_border_width_all(2)
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		
		var hover_style = style.duplicate()
		hover_style.border_color = Color(0.2, 1.0, 0.5, 0.9)
		hover_style.bg_color = Color(0.1, 0.15, 0.2, 0.9)
		
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", hover_style)
		
		var tex = load("res://Resources/icon_" + c + "_units.png")
		if tex:
			btn.icon = tex
			btn.expand_icon = true
			# Ensures icons flawlessly map inside the box symmetrically 
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hbox.add_child(btn)

func update_top_bar():
	for key in resource_keys:
		if top_bar_labels.has(key):
			top_bar_labels[key]["val"].text = str(player_resources[key])
			var inc_val = resource_incomes[key]
			var inc_l = top_bar_labels[key]["inc"]
			if inc_val > 0:
				inc_l.text = "+" + str(inc_val)
				inc_l.add_theme_color_override("font_color", Color(0.2, 0.8, 0.4))
			elif inc_val < 0:
				inc_l.text = str(inc_val)
				inc_l.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			else:
				inc_l.text = "0"
				inc_l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


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
