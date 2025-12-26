@tool
extends EditorPlugin

const SINGULAR_SELECTION : bool = false
const TITLE_BASE : String = "Make Folders in: \n\t"

var dialog: AcceptDialog
var text_edit : TextEdit

var make_folder_shortcut : Shortcut = Shortcut.new()
var submit_shortcut : Shortcut = Shortcut.new()

func _enter_tree() -> void:



	dialog = AcceptDialog.new()
	dialog.canceled.connect(func()->void:dialog.title = TITLE_BASE)
	dialog.title = TITLE_BASE
	dialog.ok_button_text = "MAKE THEM!"
	dialog.min_size = Vector2(420, 300)

	text_edit = TextEdit.new()
	text_edit.placeholder_text = "Enter folder names"
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_edit.gui_input.connect(_on_textedit_input)
	
	dialog.add_child(text_edit)

	dialog.confirmed.connect(_on_confirmed)
	get_editor_interface().get_base_control().add_child(dialog)

	# Open Dialog Shortcut
	var key_event : InputEventKey = InputEventKey.new()
	key_event.keycode = KEY_M
	key_event.ctrl_pressed = true
	key_event.shift_pressed = true
	
	# MAKE IT Shortcut
	var make_it_key_event : InputEventKey = InputEventKey.new()
	make_it_key_event.keycode = KEY_ENTER
	make_it_key_event.ctrl_pressed = true
	
	
	make_folder_shortcut.events.append(key_event)
	submit_shortcut.events.append(make_it_key_event)

	add_tool_menu_item("MkFolders", _open_dialog,)
	key_event.command_or_control_autoremap = true

func _exit_tree() -> void:
	remove_tool_menu_item("MkFolders")
	dialog.queue_free()

func _open_dialog() -> void:
	var selected = get_editor_interface().get_selected_paths()
	if SINGULAR_SELECTION: selected.resize(1)

	if selected.is_empty():
		dialog.title += "Working on root res://"
	else:
		dialog.title += "Working on Dir %s" % selected[0] if SINGULAR_SELECTION else " | Working on (%s) Directories" % selected.size()

	dialog.show()
	text_edit.text = ""
	text_edit.placeholder_text = "Working Directories: \n\t"
	for _a_path_name : String in selected:
		text_edit.placeholder_text += "- " + _a_path_name + "\n\t"
	
	if selected.is_empty(): text_edit.placeholder_text += "res://"

	dialog.popup_centered()
	var _text_edit : TextEdit = dialog.get_child(0)
	_text_edit.grab_focus()

func _on_confirmed() -> void:
	var editor_fs : EditorFileSystem = get_editor_interface().get_resource_filesystem()
	var selected : PackedStringArray = get_editor_interface().get_selected_paths()

	var created_paths : PackedStringArray 

# IF YOU WANNA DISABLE MAKING IN "RES://" UNCOMMENT IT
#	if selected.is_empty():
#		push_warning("No folder selected")
#		return
#----

	if SINGULAR_SELECTION: selected.resize(1)
	if selected.is_empty(): selected.append("res://")

	for _path : String in selected:
		if not _path.ends_with("/"):
			_path = _path.get_base_dir()
	
		for line in text_edit.text.split("\n"):
			var path = line.strip_edges()
			if path == "":
				continue
		
			created_paths.append(_path.path_join(path))

	_mkdir_p(created_paths)	
	editor_fs.scan()

func _mkdir_p(paths: PackedStringArray) -> void:
	var undo : EditorUndoRedoManager = get_editor_interface().get_editor_undo_redo()
	undo.create_action("MkFolders: Create Folders")
	print_rich("[color=slate_gray]Worked On Folders:[/color]")
	for path : String in paths:
		undo.add_do_method(self, "_create_dir", path)
		undo.add_undo_method(self, "_remove_dir", path)
	
	undo.commit_action()

func _create_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)
	var editor_fs : EditorFileSystem = get_editor_interface().get_resource_filesystem()
	editor_fs.scan()

func _remove_dir(path: String) -> void:
	if DirAccess.dir_exists_absolute(path):
		DirAccess.remove_absolute(path)
	var editor_fs : EditorFileSystem = get_editor_interface().get_resource_filesystem()
	editor_fs.scan()

func _input(event: InputEvent) -> void:
	if make_folder_shortcut.matches_event(event) and event.is_pressed() and not event.is_echo():
		_open_dialog()

func _hide_dialog() -> void:
	dialog.title = TITLE_BASE
	dialog.hide()

func _on_textedit_input(event: InputEvent) -> void:
	if submit_shortcut.matches_event(event) and event.is_pressed() and not event.is_echo():
		_on_confirmed()
		_hide_dialog()