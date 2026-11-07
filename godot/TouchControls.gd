extends CanvasLayer

# Android/iOS need simultaneous movement + jumping without a keyboard.
# TouchScreenButton handles multiple fingers; no mouse-emulation dependency.
var overlay: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return

	overlay = Node2D.new()
	add_child(overlay)
	_add_action("◀", "move_left", Vector2(8, 162))
	_add_action("▶", "move_right", Vector2(52, 162))
	_add_action("▼", "move_down", Vector2(96, 162))
	_add_action("ПРЫЖ", "jump", Vector2(206, 162))


func _add_action(label_text: String, action_name: String, offset: Vector2) -> void:
	var button := TouchScreenButton.new()
	button.action = action_name
	button.texture_normal = _make_texture(Color(0.14, 0.22, 0.33, 0.73))
	button.texture_pressed = _make_texture(Color(0.32, 0.51, 0.70, 0.92))
	button.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	button.passby_press = true
	button.position = offset
	overlay.add_child(button)

	var caption := Label.new()
	caption.text = label_text
	caption.position = Vector2(1, 7)
	caption.size = Vector2(40, 30)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 9 if label_text == "ПРЫЖ" else 18)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(caption)


func _make_texture(color: Color) -> ImageTexture:
	var picture := Image.create(42, 34, false, Image.FORMAT_RGBA8)
	picture.fill(Color(color.r, color.g, color.b, 0.0))
	picture.fill_rect(Rect2i(1, 1, 40, 32), color)
	return ImageTexture.create_from_image(picture)


func _process(_delta: float) -> void:
	if not is_instance_valid(overlay):
		return
	var game = get_parent()
	overlay.visible = game.game_mode == game.GM_ROUND and not get_tree().paused
