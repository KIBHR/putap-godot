extends CanvasLayer

# Native desktop controls. The 256x256 gameplay area and its keyboard
# bindings are independent from this mouse-only toolbar.
var status_label: Label
var pause_button: Button
var sound_button: Button
var save_button: Button
var load_button: Button
var continue_button: Button
var new_button: Button
var title_actions: HBoxContainer
var pause_overlay: PanelContainer
var help_panel: PanelContainer
var was_paused_before_help := false


func _ready() -> void:
	# Menus work during a pause. The game itself stops processing as usual.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return

	status_label = Label.new()
	status_label.position = Vector2(3, 192)
	status_label.size = Vector2(250, 11)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 8)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)

	var pause_text := Label.new()
	pause_text.text = "ПАУЗА"
	pause_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_text.add_theme_font_size_override("font_size", 16)
	pause_overlay = PanelContainer.new()
	pause_overlay.position = Vector2(67, 90)
	pause_overlay.size = Vector2(122, 38)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.add_child(pause_text)
	pause_overlay.visible = false
	add_child(pause_overlay)

	# Shortcuts are also shown on the title screen via H (Controls).
	title_actions = HBoxContainer.new()
	title_actions.position = Vector2(16, 149)
	title_actions.size = Vector2(224, 21)
	title_actions.add_theme_constant_override("separation", 4)
	add_child(title_actions)
	continue_button = add_button(title_actions, "Продолжить (C)", "Загрузить сохранённую игру", _load_game)
	new_button = add_button(title_actions, "Новая игра (Space)", "Начать с первого уровня", _new_game)

	var controls := VBoxContainer.new()
	controls.anchor_left = 0.0
	controls.anchor_right = 1.0
	controls.anchor_top = 1.0
	controls.anchor_bottom = 1.0
	controls.offset_left = 4.0
	controls.offset_right = -4.0
	controls.offset_top = -53.0
	controls.offset_bottom = -2.0
	controls.add_theme_constant_override("separation", 1)
	add_child(controls)

	var window_row := HBoxContainer.new()
	window_row.custom_minimum_size.y = 16.0
	window_row.add_theme_constant_override("separation", 2)
	controls.add_child(window_row)
	add_button(window_row, "Окно F10", "Оконный режим", _set_windowed)
	add_button(window_row, "Экран Enter", "Полноэкранный режим (Enter)", _set_fullscreen)
	add_button(window_row, "Выход Esc", "Закрыть игру (Esc)", _close_game)

	var options_row := HBoxContainer.new()
	options_row.custom_minimum_size.y = 16.0
	options_row.add_theme_constant_override("separation", 2)
	controls.add_child(options_row)
	pause_button = add_button(options_row, "Пауза P", "Пауза / продолжить", _toggle_pause)
	sound_button = add_button(options_row, "Звук M: ВКЛ", "Включить / выключить звук", _toggle_sound)

	var saves_row := HBoxContainer.new()
	saves_row.custom_minimum_size.y = 16.0
	saves_row.add_theme_constant_override("separation", 2)
	controls.add_child(saves_row)
	save_button = add_button(saves_row, "Сохр. F5", "Сохранить игру", _save_game)
	load_button = add_button(saves_row, "Загруз. F9", "Загрузить сохранение", _load_game)
	add_button(saves_row, "Клавиши H", "Показать / скрыть клавиши управления", _toggle_help)

	# Help works during gameplay; it freezes the game until closed.
	help_panel = PanelContainer.new()
	help_panel.position = Vector2(8, 24)
	help_panel.size = Vector2(240, 166)
	help_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var help_text := Label.new()
	help_text.text = "УПРАВЛЕНИЕ (H — закрыть)\n\n" + \
		"← / → , A / D — идти\n" + \
		"↓ / S — ключ или блок\n" + \
		"Пробел / Shift / Ctrl / Alt — прыжок\n" + \
		"Enter — окно / полный экран\n" + \
		"Esc — выход\n" + \
		"P — пауза / продолжить\n" + \
		"M — звук ВКЛ / ВЫКЛ\n" + \
		"F5 — сохранить  F9 — загрузить\n" + \
		"C — продолжить (на старте)\n" + \
		"Пробел — новая игра (на старте)"
	help_text.add_theme_font_size_override("font_size", 9)
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Center text in the 240x166 reference panel.
	help_panel.add_child(help_text)
	help_panel.visible = false
	add_child(help_panel)

	refresh_save_menu()
	_update_state_labels()
	if Engine.is_embedded_in_editor():
		status_label.text = "Отключите Embed Game для полного экрана"
	else:
		call_deferred("_center_window")


func add_button(bar: HBoxContainer, caption: String, hint: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.tooltip_text = hint
	# Avoid arrow/Space gameplay accidentally activating Exit or Save.
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 9)
	button.pressed.connect(action)
	bar.add_child(button)
	return button


func refresh_save_menu(message: String = "") -> void:
	if not is_instance_valid(save_button):
		return
	var game = get_parent()
	var on_title: bool = game.game_mode == game.GM_TITLE
	title_actions.visible = on_title
	continue_button.disabled = not game.has_saved_game()
	save_button.disabled = game.game_mode != game.GM_ROUND
	load_button.disabled = not game.has_saved_game()
	pause_button.disabled = game.game_mode != game.GM_ROUND
	if is_instance_valid(status_label) and not message.is_empty():
		status_label.text = message


func _update_state_labels() -> void:
	if is_instance_valid(pause_button):
		pause_button.text = "Продолжить P" if get_tree().paused else "Пауза P"
	if is_instance_valid(sound_button):
		sound_button.text = "Звук M: ВЫКЛ" if is_sound_muted() else "Звук M: ВКЛ"
	if is_instance_valid(pause_overlay):
		pause_overlay.visible = get_tree().paused and not help_panel.visible


func is_sound_muted() -> bool:
	var master := AudioServer.get_bus_index("Master")
	return master >= 0 and AudioServer.is_bus_mute(master)


func _toggle_pause() -> void:
	if get_parent().game_mode != get_parent().GM_ROUND or help_panel.visible:
		return
	get_tree().paused = not get_tree().paused
	_update_state_labels()


func _toggle_sound() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return
	AudioServer.set_bus_mute(master, not AudioServer.is_bus_mute(master))
	_update_state_labels()


func _save_game() -> void:
	if get_parent().save_game():
		status_label.text = "Игра сохранена (F5)"
	else:
		status_label.text = "Сохранение доступно только в игре"


func _load_game() -> void:
	if get_parent().load_game():
		_close_help()
		_update_state_labels()
		status_label.text = "Игра загружена (F9)"
	else:
		status_label.text = "Нет подходящего сохранения"


func _new_game() -> void:
	_close_help()
	get_parent().start_new_game()
	_update_state_labels()
	status_label.text = ""


func _toggle_help() -> void:
	if help_panel.visible:
		_close_help()
		return
	was_paused_before_help = get_tree().paused
	help_panel.visible = true
	get_tree().paused = true
	_update_state_labels()


func _close_help() -> void:
	if not is_instance_valid(help_panel) or not help_panel.visible:
		return
	help_panel.visible = false
	get_tree().paused = was_paused_before_help
	_update_state_labels()


func _center_window() -> void:
	if not Engine.is_embedded_in_editor() and get_window().mode == Window.MODE_WINDOWED:
		get_window().move_to_center()


func _set_windowed() -> void:
	if Engine.is_embedded_in_editor():
		if is_instance_valid(status_label):
			status_label.text = "Отключите Embed Game в редакторе"
		return
	var window := get_window()
	window.mode = Window.MODE_WINDOWED
	window.size = Vector2i(768, 768)
	call_deferred("_center_window")


func _set_fullscreen() -> void:
	if Engine.is_embedded_in_editor():
		if is_instance_valid(status_label):
			status_label.text = "Отключите Embed Game в редакторе"
		return
	get_window().mode = Window.MODE_FULLSCREEN


func _toggle_fullscreen() -> void:
	if get_window().mode == Window.MODE_FULLSCREEN or get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		_set_windowed()
	else:
		_set_fullscreen()


func _close_game() -> void:
	get_tree().paused = false
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless" or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	# Physical keys work independently of Russian/English keyboard layout.
	var key := key_event.keycode
	if key_event.physical_keycode in [KEY_P, KEY_M, KEY_H, KEY_C, KEY_N]:
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
		KEY_H:
			_toggle_help()
		KEY_F5:
			_save_game()
		KEY_F9:
			_load_game()
		KEY_C:
			if get_parent().game_mode == get_parent().GM_TITLE:
				_load_game()
			else:
				return
		KEY_N:
			if get_parent().game_mode == get_parent().GM_TITLE:
				_new_game()
			else:
				return
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
