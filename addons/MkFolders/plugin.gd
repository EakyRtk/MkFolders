@tool
extends EditorPlugin

const SINGULAR_SELECTION : bool = false
const TITLE_BASE : String = "Make Folders in: \n\t"

var dialog: AcceptDialog
var file_dialog : FileDialog
var text_edit : TextEdit
var main_vbox : VBoxContainer
var h_split : HSplitContainer
var preview_tree : Tree

var make_folder_shortcut : Shortcut = Shortcut.new()
var submit_shortcut : Shortcut = Shortcut.new()

var base_path : String

var can_undo : bool = false

func _enter_tree() -> void:
	base_path = "user://mkfolder/templates/" 
	if not DirAccess.dir_exists_absolute(base_path):
		DirAccess.make_dir_recursive_absolute(base_path)


	# CONTENTS OUR DIALOG BUBBLE WILL HAVE

	# - MAIN BOX -
	main_vbox = VBoxContainer.new()
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# - H SPLIT HAVING OUR 'TEXT EDIT | TREE'
	h_split = HSplitContainer.new()
	h_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_split.split_offset = 20 
	main_vbox.add_child(h_split)

	# - TEXT EDIT -
	text_edit = TextEdit.new()
	text_edit.placeholder_text = "Enter folder names"
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.gui_input.connect(_on_textedit_input)
	text_edit.text_changed.connect(_update_preview)
	h_split.add_child(text_edit)

	# - PREVIEW TREE -
	preview_tree = Tree.new()
	preview_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_tree.columns = 1
	#preview_tree.hide_folding = true
	preview_tree.hide_root = true
	preview_tree.set_column_title(0, "Tree Preview")
	preview_tree.set_column_title_alignment(0, HORIZONTAL_ALIGNMENT_CENTER)
	h_split.add_child(preview_tree)
	# - - -

	# - FILE DIALOG -
	file_dialog = FileDialog.new()
	file_dialog.filters = PackedStringArray(["*.txt"])
	file_dialog.file_selected.connect(func(selected_path: String)->void:
		match file_dialog.file_mode:
			FileDialog.FILE_MODE_OPEN_FILE:
				var f = FileAccess.open(selected_path, FileAccess.READ)
				text_edit.text = f.get_as_text()
				f.close()
			FileDialog.FILE_MODE_SAVE_FILE:
				var f = FileAccess.open(selected_path, FileAccess.WRITE)
				if f:
					f.store_string(text_edit.text)
					f.close()
	)

	#----------------

	# DIALOG SETTING
	dialog = AcceptDialog.new()
	dialog.title = TITLE_BASE
	dialog.ok_button_text = "Create"
	dialog.add_button("Templates", false, "select_template")
	dialog.add_button("Save Template", false, "save_template")
	dialog.min_size = Vector2(520, 300)
	#		- adding contents -
	dialog.add_child(main_vbox)
	dialog.add_child(file_dialog)

	#	- dialog signals -
	dialog.custom_action.connect(_file_dialog)
	dialog.canceled.connect(func()->void:dialog.title = TITLE_BASE)
	dialog.confirmed.connect(_on_confirmed)
	#----------------

	get_editor_interface().get_base_control().add_child(dialog)

	var editor_settings: EditorSettings = get_editor_interface().get_editor_settings()

	var open_dialog_path: String = "MkFolders/Open Dialog"
	if not editor_settings.has_setting(open_dialog_path):
		var key_event: InputEventKey = InputEventKey.new()
		key_event.keycode = KEY_N
		key_event.shift_pressed = true
		
		var default_shortcut: Shortcut = Shortcut.new()
		default_shortcut.events = [key_event]
		editor_settings.add_shortcut(open_dialog_path, default_shortcut)

	make_folder_shortcut = editor_settings.get_shortcut(open_dialog_path)

	var submit_path: String = "MkFolders/Submit Dialog"
	if not editor_settings.has_setting(submit_path):
		var make_it_key_event: InputEventKey = InputEventKey.new()
		make_it_key_event.keycode = KEY_ENTER
		make_it_key_event.ctrl_pressed = true
		
		var default_submit_shortcut: Shortcut = Shortcut.new()
		default_submit_shortcut.events = [make_it_key_event]
		editor_settings.add_shortcut(submit_path, default_submit_shortcut)
		
	submit_shortcut = editor_settings.get_shortcut(submit_path)
	add_tool_menu_item("MkFolders", _open_dialog)

func _file_dialog(action_name: String) -> void:
	if action_name == "select_template":
		file_dialog.access = FileDialog.ACCESS_USERDATA
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_dialog.current_path = base_path
		file_dialog.current_dir = base_path
		file_dialog.popup()
	elif action_name == "save_template":
		file_dialog.access = FileDialog.ACCESS_USERDATA
		file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		file_dialog.current_path = base_path
		file_dialog.current_dir = base_path
		file_dialog.popup()

func _exit_tree() -> void:
	remove_tool_menu_item("MkFolders")
	dialog.queue_free()
	preview_tree.clear()
	preview_tree.queue_free()

func _open_dialog() -> void:
	preview_tree.clear()
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
	text_edit.grab_focus()
	
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
			if path == "" or path.begins_with("#"):
				continue
		
			created_paths.append(_path.path_join(path))

	_mkdir_p(created_paths)	
	editor_fs.scan()

func _mkdir_p(paths: PackedStringArray) -> void:
	print_rich("[color=slate_gray]MkFolders: Folders Created[/color]")
	if can_undo:
		var undo : EditorUndoRedoManager = get_editor_interface().get_editor_undo_redo()
		undo.create_action("MkFolders: Create Folders")
		for path : String in paths:
			undo.add_do_method(self, "_create_dir", path)
			undo.add_undo_method(self, "_remove_dir", path)
	
		undo.commit_action()
	else:
		for path : String in paths:
			_create_dir(path)
	
	
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


func _update_preview() -> void:
	preview_tree.clear()
	
	var selected = get_editor_interface().get_selected_paths()
	if SINGULAR_SELECTION: selected.resize(1)
	if selected.is_empty(): 
		selected.append("res://")
	var folder_icon: Texture2D = get_editor_interface().get_base_control().get_theme_icon("Folder", "EditorIcons")
	var root: TreeItem = preview_tree.create_item()
	
	for _path: String in selected:
		if not _path.ends_with("/"):
			_path = _path.get_base_dir()
		
		var relative_base: String = _path.replace("res://", "")
		if relative_base.ends_with("/"):
			relative_base = relative_base.trim_suffix("/")
		
		for line: String in text_edit.text.split("\n"):
			line = line.strip_edges()
			if line == "" or line.begins_with("#"):
				continue

			var target_path = relative_base.path_join(line).replace("\\", "/")
			if target_path.ends_with("/"):
				target_path = target_path.trim_suffix("/")

			var parts: PackedStringArray = target_path.split("/")
			var current_parent: TreeItem = root 
			
			for part: String in parts:
				if part.is_empty(): 
					continue
				
				var found_item: TreeItem = null
				var child_iter: TreeItem = current_parent.get_first_child()
				while child_iter:
					if child_iter.get_text(0) == part:
						found_item = child_iter
						break
					child_iter = child_iter.get_next()
				
				if found_item:
					current_parent = found_item
				else:
					var new_item: TreeItem = preview_tree.create_item(current_parent)
					new_item.set_text(0, part)
					new_item.set_icon(0, folder_icon)
					current_parent = new_item
