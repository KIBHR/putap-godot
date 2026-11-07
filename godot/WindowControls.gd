extends CanvasLayer

# Native desktop controls live in the unused area below the original 256x256
# playfield. Web exports use a separate HTML toolbar. Never focus the buttons:
# arrows and Space belong to the player, not to the UI.
var status_label: Label
var pause_button: Button
var sound_button: Button
var pause_overlay: PanelContainer


func _ready() -> void:
	# Only this node must keep receiving input while the rest of the game pauses.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return

	status_label = Label.new()
	status_label.position = Vector2(3, 192)
	status_label.size = Vector2(250, 14)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)

	var pause_label := Label.new()
	pause_label.text = "ПАУЗА"
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_label.add_theme_font_size_override("font_size", 16)
	pause_overlay = PanelContainer.new()
	pause_overlay.position = Vector2(67, 90)
	pause_overlay.size = Vector2(122, 38)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.add_child(pause_label)
	pause_overlay.visible = false
	add_child(pause_overlay)

	var controls := VBoxContainer.new()
	controls.anchor_left = 0.0
	controls.anchor_right = 1.0
	controls.anchor_top = 1.0
	controls.anchor_bottom = 1.0
	controls.offset_left = 4.0
	controls.offset_right = -4.0
	controls.offset_top = -51.0
	controls.offset_bottom = -2.0
	controls.add_theme_constant_override("separation", 2)
	add_child(controls)

	var window_row := HBoxContainer.new()
	window_row.custom_minimum_size.y = 22.0
	window_row.add_theme_constant_override("separation", 2)
	controls.add_child(window_row)
	add_button(window_row, "Окно", "Оконный режим (F10)", _set_windowed)
	add_button(window_row, "Весь экран", "Полноэкранный режим (Enter)", _set_fullscreen)
	add_button(window_row, "Выход", "Закрыть игру (Esc)", _close_game)

	var options_row := HBoxContainer.new()
	options_row.custom_minimum_size.y = 22.0
	options_row.add_theme_constant_override("separation", 2)
	controls.add_child(options_row)
	pause_button = add_button(options_row, "Пауза", "Пауза / продолжить (P)", _toggle_pause)
	sound_button = add_button(options_row, "Музыка: ВКЛ", "Включить / выключить звук (M)", _toggle_sound)
	_update_state_labels()

	if Engine.is_embedded_in_editor():
		status_label.text = "Выключите Embed Game в редакторе"
	else:
		call_deferred("_center_window")


func add_button(bar: HBoxContainer, caption: String, hint: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 10)
	button.pressed.connect(action)
	bar.add_child(button)
	return button


func _update_state_labels() -> void:
	if is_instance_valid(pause_button):
		pause_button.text = "Продолжить" if get_tree().paused else "Пауза"
	if is_instance_valid(sound_button):
		sound_button.text = "Музыка: ВЫКЛ" if is_sound_muted() else "Музыка: ВКЛ"
	if is_instance_valid(pause_overlay):
		pause_overlay.visible = get_tree().paused
	if is_instance_valid(status_label) and get_tree().paused:
		status_label.text = "ИГРА НА ПАУЗЕ — P"


func is_sound_muted() -> bool:
	var master := AudioServer.get_bus_index("Master")
	return master >= 0 and AudioServer.is_bus_mute(master)


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	_update_state_labels()
	if not get_tree().paused and is_instance_valid(status_label):
		status_label.text = ""


func _toggle_sound() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return
	AudioServer.set_bus_mute(master, not AudioServer.is_bus_mute(master))
	_update_state_labels()


func _center_window() -> void:
	if not Engine.is_embedded_in_editor() and get_window().mode == Window.MODE_WINDOWED:
		get_window().move_to_center()


func _set_windowed() -> void:
	if Engine.is_embedded_in_editor():
		if is_instance_valid(status_label):
			status_label.text = "Выключите Embed Game в редакторе"
		return
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(768, 768)
	call_deferred("_center_window")


func _set_fullscreen() -> void:
	if Engine.is_embedded_in_editor():
		if is_instance_valid(status_label):
			status_label.text = "Выключите Embed Game в редакторе"
		return
	get_window().mode = Window.MODE_FULLSCREEN


func _toggle_fullscreen() -> void:
	if get_window().mode == Window.MODE_FULLSCREEN or get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		_set_windowed()
	else:
		_set_fullscreen()


func _close_game() -> void:
	# A paused SceneTree must be restored before closing/restarting.
	get_tree().paused = false
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless" or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	# Use physical P/M positions too, so Russian keyboard layout works.
	var key := key_event.keycode
	if key_event.physical_keycode == KEY_P or key_event.physical_keycode == KEY_M:
		key = key_event.physical_keycode
	match key:
		KEY_ENTER, KEY_KP_ENTER:
			_toggle_fullscreen()
		KEY_ESCAPE:
			_close_game()
		KEY_P:
			_toggle_pause()
		KEY_M:
			_toggle_sound()
		KEY_F10:
			_set_windowed()
		KEY_F11:
			_set_fullscreen()
		KEY_Q:
			if key_event.ctrl_pressed:
				_close_game()
			else:
				return
		_:
			return
	get_viewport().set_input_as_handled()
