extends CanvasLayer
class_name UIManager

@onready var tooltip_label: Label = $TooltipLabel
var following_mouse: bool = false

var fleet_list_panel: PanelContainer
var fleet_list_container: VBoxContainer
var currently_displayed_category: String = ""

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
		
		var tex = load("res://Resources/icon_" + key + ".png")
		if tex:
			icon_rect.texture = tex
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
	
	# Explicit Tracking Modal natively wrapped accurately!
	var modal_margin = MarginContainer.new()
	modal_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	modal_margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	modal_margin.grow_horizontal = Control.GROW_DIRECTION_END
	modal_margin.add_theme_constant_override("margin_bottom", 100) # Hugs directly over the icons mathematically
	modal_margin.add_theme_constant_override("margin_left", 20)
	add_child(modal_margin)
	
	fleet_list_panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.12, 0.95)
	panel_style.border_color = Color(0.2, 0.4, 0.6, 0.8)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	fleet_list_panel.add_theme_stylebox_override("panel", panel_style)
	fleet_list_panel.custom_minimum_size = Vector2(320, 250)
	fleet_list_panel.hide()
	modal_margin.add_child(fleet_list_panel)
	
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fleet_list_panel.add_child(scroll)
	
	fleet_list_container = VBoxContainer.new()
	fleet_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fleet_list_container.add_theme_constant_override("separation", 10)
	
	var list_margin = MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 15)
	list_margin.add_theme_constant_override("margin_right", 15)
	list_margin.add_theme_constant_override("margin_top", 15)
	list_margin.add_theme_constant_override("margin_bottom", 15)
	list_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_margin.add_child(fleet_list_container)
	scroll.add_child(list_margin)
	
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
		btn.pressed.connect(_on_fleet_category_pressed.bind(c))
		hbox.add_child(btn)

func _on_fleet_category_pressed(category: String):
	if currently_displayed_category == category and fleet_list_panel.visible:
		fleet_list_panel.hide()
		currently_displayed_category = ""
		return
		
	currently_displayed_category = category
	fleet_list_panel.show()
	
	for child in fleet_list_container.get_children():
		child.queue_free()
		
	var title = Label.new()
	title.text = category.capitalize() + " Fleets"
	title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5, 1.0))
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fleet_list_container.add_child(title)
	
	var hs = HSeparator.new()
	fleet_list_container.add_child(hs)
	
	var fm = get_parent().get_node_or_null("GalaxyGenerator/FleetManager")
	var gal = get_parent().get_node_or_null("GalaxyGenerator")
	if not fm or not gal: return
	
	var found = false
	for f in fm.global_fleets:
		# Safety check structurally for newly injected faction keys globally mapped securely!
		if f.has("fleet_class") and f.has("faction") and f.has("name"):
			if f["fleet_class"] == category and f["faction"] == fm.player_faction:
				found = true
				found = true
				var item_box = PanelContainer.new()
				
				# Setup clean baseline styling natively
				var sb = StyleBoxFlat.new()
				sb.bg_color = Color(0,0,0,0) # Invisible initially dynamically!
				item_box.add_theme_stylebox_override("panel", sb)
				item_box.set_meta("base_style", sb)
				
				var vbox = VBoxContainer.new()
				item_box.add_child(vbox)
				
				var name_lbl = Button.new()
				name_lbl.text = f["name"]
				name_lbl.flat = true
				name_lbl.alignment = HORIZONTAL_ALIGNMENT_LEFT
				
				var sb_empty = StyleBoxEmpty.new()
				name_lbl.add_theme_stylebox_override("normal", sb_empty)
				name_lbl.add_theme_stylebox_override("hover", sb_empty)
				name_lbl.add_theme_stylebox_override("pressed", sb_empty)
				name_lbl.add_theme_stylebox_override("focus", sb_empty)
				
				name_lbl.add_theme_font_size_override("font_size", 16)
				name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
				name_lbl.add_theme_color_override("font_hover_color", Color(0.2, 1.0, 0.5, 1.0))
				name_lbl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				
				# Explicitly securely capture local primitive arrays intrinsically overriding engine scopes!
				name_lbl.pressed.connect(_on_fleet_name_pressed.bind(f))
					
				vbox.add_child(name_lbl)
				
				var loc_lbl = Label.new()
				var loc_name = "Deep Space"
				if f.has("system_index") and f["system_index"] != -1 and f["system_index"] < gal.star_data.size():
					loc_name = gal.star_data[f["system_index"]]["name"]
				if f.has("is_jumping") and f["is_jumping"] and f.has("target_system"):
					loc_name = "Transit (Moving to " + gal.star_data[f["target_system"]]["name"] + ")"
				loc_lbl.text = loc_name
				loc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
				loc_lbl.add_theme_font_size_override("font_size", 14)
				loc_lbl.set_meta("fleet_ref", f) # Hard-ties the memory reference to the UI physically!
				vbox.add_child(loc_lbl)
				
				var time_lbl = Label.new()
				time_lbl.text = "Transit Time: N/A"
				time_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
				time_lbl.add_theme_font_size_override("font_size", 14)
				time_lbl.set_meta("fleet_ref", f)
				vbox.add_child(time_lbl)
				
				fleet_list_container.add_child(item_box)
				
				var small_hs = HSeparator.new()
				fleet_list_container.add_child(small_hs)
				
	if not found:
		var empty = Label.new()
		empty.text = "No active fleets."
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		fleet_list_container.add_child(empty)

func _on_fleet_name_pressed(f: Dictionary):
	var fm = get_parent().get_node_or_null("GalaxyGenerator/FleetManager")
	if fm and fm.has_method("set_selection"):
		fm.set_selection([f])
		
	# If deeply transiting currently natively, skip strict camera zoom explicitly!
	if not f.has("system_index") or f["system_index"] == -1: return
	var idx = f["system_index"]
	
	var gal = get_parent().get_node_or_null("GalaxyGenerator")
	if not gal or idx < 0 or idx >= gal.star_data.size(): return
	
	var cam = get_viewport().get_camera_3d()
	if cam and cam.has_method("focus_on_star"):
		# Natively mimic exactly the physical MainCamera collision transition physics directly from the UI state organically!
		var ring_radius = max(275.0, sqrt(gal.star_data[idx]["mass"]) * 275.0)
		cam.focus_on_star(gal.star_data[idx]["pos"], true, ring_radius)
		gal.set_system_view(idx)

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
		
	# Native tracking loop to synchronize physically moving fleet map states identically!
	if fleet_list_panel.visible and currently_displayed_category != "":
		var gal = get_parent().get_node_or_null("GalaxyGenerator")
		if gal:
			for item_box in fleet_list_container.get_children():
				if item_box is PanelContainer and item_box.get_child_count() > 0:
					var vbox = item_box.get_child(0)
					if vbox is VBoxContainer and vbox.get_child_count() > 2:
						var loc_lbl = vbox.get_child(1)
						var time_lbl = vbox.get_child(2)
						if loc_lbl.has_meta("fleet_ref"):
							var f = loc_lbl.get_meta("fleet_ref")
							var loc_name = "Deep Space"
							if f.has("system_index") and f["system_index"] != -1 and f["system_index"] < gal.star_data.size():
								loc_name = gal.star_data[f["system_index"]]["name"]
								if f.has("target_system") and f["target_system"] != -1:
									loc_name += " (navigating to " + gal.star_data[f["target_system"]]["name"] + ")"
							elif f.has("is_jumping") and f["is_jumping"] and f.has("target_system"):
								loc_name = "Transit (Moving to " + gal.star_data[f["target_system"]]["name"] + ")"
							
							var exact_text = loc_name
							if loc_lbl.text != exact_text:
								loc_lbl.text = exact_text
								
							var fm = get_parent().get_node_or_null("GalaxyGenerator/FleetManager")
							if fm and fm.has_method("get_transit_time_remaining"):
								var tr = fm.get_transit_time_remaining(f)
								if tr > 0.1:
									time_lbl.text = "Transit Time: %.1fs" % tr
								else:
									time_lbl.text = "Transit Time: 0s"
								
							# Native style rendering checking physical selected memory natively!
							var is_sel = f.has("selected") and f["selected"]
							var active_sel = item_box.get_meta("is_selected", false)
							if is_sel != active_sel:
								item_box.set_meta("is_selected", is_sel)
								var name_lbl = vbox.get_child(0)
								if is_sel:
									if name_lbl is Button: name_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5, 1.0))
								else:
									if name_lbl is Button: name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))

func show_tooltip(text: String):
	tooltip_label.text = text
	tooltip_label.show()
	following_mouse = true

func hide_tooltip():
	tooltip_label.hide()
	following_mouse = false
