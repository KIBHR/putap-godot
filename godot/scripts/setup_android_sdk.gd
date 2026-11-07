extends SceneTree

# Run under `godot --headless --editor --script ...` in CI.
# SDK paths are editor-local settings, not project export options.
func _initialize() -> void:
	var settings := EditorInterface.get_editor_settings()
	var sdk := OS.get_environment("ANDROID_HOME")
	var java := OS.get_environment("JAVA_HOME")
	if sdk.is_empty() or java.is_empty():
		push_error("ANDROID_HOME and JAVA_HOME must be configured")
		quit(1)
		return
	settings.set_setting("export/android/android_sdk_path", sdk)
	settings.set_setting("export/android/java_sdk_path", java)
	print("Configured Android SDK: ", sdk)
	quit(0)
