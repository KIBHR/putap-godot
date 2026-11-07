extends CanvasLayer

# Desktop controls: keep the game at its native 256x256 logical size.
# The bottom 64 pixels are empty in the original layout, so buttons
# and status text do not cover the level or scoreboard.
var status_label: Label


func _ready() -> void:
	# No native window controls are needed in browser exports or headless tests.
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return

	status_label = Label.new()
	status_label.position = Vector2(4, 201)
	status_label.size = Vector2(248, 19)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)

	var bar := HBoxContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 4.0
	bar.offset_right = -4.0
	bar.offset_top = -29.0
	bar.offset_bottom = -4.0
	bar.add_theme_constant_override("separation", 3)
	add_child(bar)
	add_button(bar, "Окно", "Оконный режим (F10)", _set_windowed)
	add_button(bar, "Весь экран", "Полноэкранный режим (F11)", _set_fullscreen)
	add_button(bar, "Выход", "Закрыть игру (Ctrl+Q)", _close_game)

	if Engine.is_embedded_in_editor():
		status_label.text = "Выключите Embed Game в редакторе"
	else:
		call_deferred("_center_window")


func add_button(bar: HBoxContainer, caption: String, hint: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.tooltip_text = hint
	# Gameplay uses arrows and Space, which otherwise navigate and press
	# focused Godot buttons (including the Exit button).
	# These controls remain clickable with the mouse.
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(action)
	bar.add_child(button)


func _center_window() -> void:
	if not Engine.is_embedded_in_editor() and get_window().mode == Window.MODE_WINDOWED:
		get_window().move_to_center()


func _set_windowed() -> void:
	if Engine.is_embedded_in_editor():
		status_label.text = "Выключите Embed Game в редакторе"
		return
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(768, 768)
	status_label.text = "Оконный режим"
	call_deferred("_center_window")


func _set_fullscreen() -> void:
	if Engine.is_embedded_in_editor():
		status_label.text = "Выключите Embed Game в редакторе"
		return
	get_window().mode = Window.MODE_FULLSCREEN
	status_label.text = "Полноэкранный режим"


func _close_game() -> void:
	get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	if OS.has_feature("web") or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F11:
		_set_fullscreen()
	elif key_event.keycode == KEY_F10 or (key_event.keycode == KEY_ESCAPE and get_window().mode == Window.MODE_FULLSCREEN):
		_set_windowed()
	elif key_event.keycode == KEY_Q and key_event.ctrl_pressed:
		_close_game()
	else:
		return
	get_viewport().set_input_as_handled()
