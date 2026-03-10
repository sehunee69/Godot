extends Control

@onready var btn_start    : Button = $Start
@onready var btn_quit     : Button = $Quit

var settings_scene = preload("res://settings_menu.tscn")

func _ready():
	# Make sure nothing is paused from a previous session
	get_tree().paused = false

	if btn_start:
		btn_start.pressed.connect(_on_start)
	else:
		push_error("Start button not found!")

	if btn_quit:
		btn_quit.pressed.connect(_on_quit)
	else:
		push_error("Quit button not found!")

func _on_start():
	get_tree().change_scene_to_file("res://main.tscn")  # ← change to your actual scene path

func _on_load():
	# Hook up your save system here later
	print("Load not yet implemented")

func _on_settings():
	var settings = settings_scene.instantiate()
	add_child(settings)

func _on_quit():
	get_tree().quit()
