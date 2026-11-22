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
		for a in args:
			if a.begins_with("--port="):
				port = int(a.get_slice("=", 1))
		if server.start(port) != OK:
			get_tree().quit(1)
	else:
		get_tree().change_scene_to_file.call_deferred(CLIENT_SCENE)
