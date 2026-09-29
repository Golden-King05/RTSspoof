extends CanvasLayer
class_name MainMenu
## The very first screen: Play / Quit, plus a self-updater. There's no
## GitHub Release for this project (publishing one requires API/web-UI
## access this app doesn't have), so instead it checks a plain VERSION
## file committed straight to the repo and, in an exported Windows build,
## downloads and installs the matching exe next to it -- no separate
## launcher or Godot editor needed.

signal play_pressed

## Bump this (and push a matching releases/latest/VERSION + RTSspoof.exe,
## see the README's "Publishing a new Windows build" section) whenever a
## new build goes out, so running copies can tell they're out of date.
const CURRENT_VERSION := "v1.0.5"
const RAW_BASE := "https://raw.githubusercontent.com/Golden-King05/RTSspoof/claude/rts-aoe2-clone-game-8k7moo/releases/latest"
const VERSION_CHECK_URL := RAW_BASE + "/VERSION"
const EXE_DOWNLOAD_URL := RAW_BASE + "/RTSspoof.exe"
const UPDATE_HELPER_NAME := "_rtsspoof_apply_update.bat"
const DOWNLOADED_EXE_NAME := "_rtsspoof_update_download.exe"

var _status_label: Label
var _update_button: Button
var _play_button: Button

var _check_http: HTTPRequest
var _download_http: HTTPRequest
var _latest_tag: String = ""
var _is_editor_run: bool = false


func _ready() -> void:
	layer = 40
	_is_editor_run = OS.has_feature("editor")

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.07, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -180
	vbox.offset_right = 180
	vbox.offset_top = -140
	vbox.offset_bottom = 140
	vbox.add_theme_constant_override("separation", 14)
	add_child(vbox)

	var title := Label.new()
	title.text = "RTSspoof"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "An AoE2-style RTS prototype"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	_play_button = Button.new()
	_play_button.text = "Play"
	_play_button.custom_minimum_size = Vector2(200, 44)
	_play_button.pressed.connect(func() -> void: play_pressed.emit())
	vbox.add_child(_play_button)

	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.custom_minimum_size = Vector2(200, 40)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit_button)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer2)

	_status_label = Label.new()
	_status_label.text = "Version %s -- checking for updates..." % CURRENT_VERSION
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_label.custom_minimum_size = Vector2(360, 0)
	vbox.add_child(_status_label)

	_update_button = Button.new()
	_update_button.text = "Download Update"
	_update_button.custom_minimum_size = Vector2(200, 36)
	_update_button.visible = false
	_update_button.pressed.connect(_on_update_pressed)
	vbox.add_child(_update_button)

	_check_http = HTTPRequest.new()
	add_child(_check_http)
	_check_http.request_completed.connect(_on_release_checked)

	_download_http = HTTPRequest.new()
	_download_http.use_threads = true
	add_child(_download_http)
	_download_http.request_completed.connect(_on_download_completed)

	_check_for_updates()


func _check_for_updates() -> void:
	# Raw file URLs get cached aggressively by GitHub's CDN; a cache-busting
	# query param keeps this check honest.
	var url: String = VERSION_CHECK_URL + "?t=%d" % Time.get_unix_time_from_system()
	var err: int = _check_http.request(url)
	if err != OK:
		_status_label.text = "Version %s -- couldn't reach GitHub to check for updates." % CURRENT_VERSION


func _on_release_checked(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_status_label.text = "Version %s (up to date check failed)" % CURRENT_VERSION
		return

	_latest_tag = body.get_string_from_utf8().strip_edges()
	if _latest_tag == "" or _latest_tag == CURRENT_VERSION:
		_status_label.text = "Version %s (up to date)" % CURRENT_VERSION
		return

	if _is_editor_run:
		_status_label.text = "Version %s -- update %s is available (download/auto-install only works in an exported build)." % [CURRENT_VERSION, _latest_tag]
		return

	_status_label.text = "Version %s -- update %s is available!" % [CURRENT_VERSION, _latest_tag]
	_update_button.visible = true


func _on_update_pressed() -> void:
	_update_button.disabled = true
	_status_label.text = "Downloading update %s..." % _latest_tag

	var exe_dir: String = OS.get_executable_path().get_base_dir()
	var download_path: String = exe_dir.path_join(DOWNLOADED_EXE_NAME)
	_download_http.download_file = download_path

	var url: String = EXE_DOWNLOAD_URL + "?t=%d" % Time.get_unix_time_from_system()
	var err: int = _download_http.request(url)
	if err != OK:
		_status_label.text = "Update download failed to start."
		_update_button.disabled = false


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_status_label.text = "Update download failed."
		_update_button.disabled = false
		return
	_status_label.text = "Update downloaded. Restarting to install..."
	_apply_update_and_restart()


## Windows can't overwrite a running .exe, so this writes a tiny batch
## script that waits for this process to exit, moves the freshly
## downloaded exe over the current one, relaunches it, then deletes
## itself. We launch that script detached and quit immediately.
func _apply_update_and_restart() -> void:
	var exe_path: String = OS.get_executable_path()
	var exe_dir: String = exe_path.get_base_dir()
	var downloaded_path: String = exe_dir.path_join(DOWNLOADED_EXE_NAME)
	var bat_path: String = exe_dir.path_join(UPDATE_HELPER_NAME)

	var bat_lines: PackedStringArray = [
		"@echo off",
		"setlocal",
		"set NEWEXE=\"%s\"" % downloaded_path,
		"set OLDEXE=\"%s\"" % exe_path,
		"set TRIES=0",
		":retry",
		"set /a TRIES+=1",
		"move /y %NEWEXE% %OLDEXE% >nul 2>&1",
		"if exist %NEWEXE% if %TRIES% LSS 15 (",
		"  timeout /t 1 /nobreak >nul",
		"  goto retry",
		")",
		"start \"\" %OLDEXE%",
		"del \"%~f0\"",
	]

	var f: FileAccess = FileAccess.open(bat_path, FileAccess.WRITE)
	if f == null:
		_status_label.text = "Update downloaded, but couldn't write the installer script. Replace the .exe manually."
		_update_button.disabled = false
		return
	for line in bat_lines:
		f.store_line(line)
	f.close()

	OS.create_process("cmd.exe", ["/c", bat_path])
	get_tree().quit()
