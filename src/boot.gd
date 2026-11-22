extends Node
## Точка входа. Режим выбирается автоматически:
## сервер, если экспорт с фичей dedicated_server или передан аргумент --server.

const CLIENT_SCENE := "res://scenes/demo.tscn"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if OS.has_feature("dedicated_server") or "--server" in args:
		var server := ServerMain.new()
		add_child(server)
		var port := NetConfig.DEFAULT_PORT
		var db_path := ServerMain.DEFAULT_DB_PATH
		for a in args:
			if a.begins_with("--port="):
				port = int(a.trim_prefix("--port="))
			elif a.begins_with("--db="):
				db_path = a.trim_prefix("--db=")
		if server.start(port, db_path) != OK:
			get_tree().quit(1)
	else:
		get_tree().change_scene_to_file.call_deferred(CLIENT_SCENE)
