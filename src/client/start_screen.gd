class_name StartScreen
extends Node

const CAMPAIGN := "res://scenes/demo.tscn"

var pilot: DunesPilotClient

@onready var screen: Control = %Screen
@onready var modes: VBoxContainer = %Modes
@onready var login: VBoxContainer = %Login
@onready var connecting: VBoxContainer = %Connecting
@onready var port_input: LineEdit = %Port
@onready var key_input: LineEdit = %AccessKey
@onready var status: Label = %Status


func _ready() -> void:
	port_input.text = str(NetConfig.DEFAULT_PORT)
	%Campaign.pressed.connect(func(): get_tree().change_scene_to_file(CAMPAIGN))
	%Online.pressed.connect(_show_login)
	%LoginBack.pressed.connect(_show_modes)
	%Connect.pressed.connect(_connect)
	key_input.text_submitted.connect(func(_text): _connect())
	%Cancel.pressed.connect(_finish_pilot.bind(""))
	_show_modes()


func _show_modes() -> void:
	screen.show()
	modes.show()
	login.hide()
	connecting.hide()
	key_input.clear()
	status.hide()
	%Campaign.grab_focus()


func _show_login(message := "") -> void:
	screen.show()
	modes.hide()
	connecting.hide()
	login.show()
	status.text = message
	status.visible = not message.is_empty()
	key_input.grab_focus()


func _connect() -> void:
	if pilot != null:
		return
	var port_text := port_input.text.strip_edges()
	if not port_text.is_valid_int() or port_text.to_int() < 1 or port_text.to_int() > 65535:
		_show_login("Введите порт от 1 до 65535.")
		port_input.grab_focus()
		return
	var key := NetConfig.parse_login_key(key_input.text)
	if key.is_empty():
		_show_login("Ключ должен содержать 64 шестнадцатеричных символа.")
		return
	key_input.clear()
	login.hide()
	status.hide()
	connecting.show()
	%Cancel.grab_focus()
	pilot = DunesPilotClient.new()
	pilot.allow_return = true
	add_child(pilot)
	pilot.entered_world.connect(screen.hide)
	var attempt := pilot
	pilot.connection_stopped.connect(func(message): _finish_attempt.call_deferred(attempt, message))
	pilot.exit_requested.connect(func(): _finish_attempt.call_deferred(attempt, ""))
	pilot.start(port_text.to_int(), key)


func _finish_attempt(attempt: DunesPilotClient, message: String) -> void:
	if is_instance_valid(attempt) and pilot == attempt:
		_finish_pilot(message)


func _finish_pilot(message: String) -> void:
	if pilot == null:
		return
	remove_child(pilot)
	pilot.queue_free()
	pilot = null
	if message.is_empty():
		_show_modes()
	else:
		_show_login(message)
