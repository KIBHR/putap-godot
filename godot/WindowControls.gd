extends CanvasLayer

# Keep the native controls above the 256x256 game view. Browser builds use
# the separate HTML toolbar, so their playfield remains unobstructed.
func _ready() -> void:
	if OS.has_feature("web"):
		return
	var bar := HBoxContainer.new()
	bar.anchor_left = 1.0
	bar.anchor_right = 1.0
	bar.offset_left = -78.0
	bar.offset_right = -2.0
	bar.offset_top = 1.0
	bar.offset_bottom = 21.0
	bar.add_theme_constant_override("separation", 2)
	add_child(bar)
	add_button(bar, "□", "Оконный режим (F10)", _set_windowed)
	add_button(bar, "⛶", "На весь экран (F11)", _set_fullscreen)
	add_button(bar, "×", "Закрыть игру (Ctrl+Q)", _close_game)
	call_deferred("_center_window")


func add_button(bar: HBoxContainer, symbol: String, hint: String, action: Callable) -> void:
	var button := Button.new()
	button.text = symbol
	button.tooltip_text = hint
	button.custom_minimum_size = Vector2(24, 20)
	button.pressed.connect(action)
	bar.add_child(button)


func _center_window() -> void:
	if get_window().mode == Window.MODE_WINDOWED:
		get_window().move_to_center()


func _set_windowed() -> void:
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(768, 768)
	window.move_to_center()


func _set_fullscreen() -> void:
	get_window().mode = Window.MODE_FULLSCREEN


func _close_game() -> void:
	get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	if OS.has_feature("web") or not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_F11:
		_set_fullscreen()
	elif event.keycode == KEY_F10 or (event.keycode == KEY_ESCAPE and get_window().mode == Window.MODE_FULLSCREEN):
		_set_windowed()
	elif event.keycode == KEY_Q and event.ctrl_pressed:
		_close_game()
	else:
		return
	get_viewport().set_input_as_handled()
