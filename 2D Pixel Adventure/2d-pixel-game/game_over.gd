extends CanvasLayer

@onready var retry_button: Button = $ColorRect/VBoxContainer/Button
@onready var btn_main_menu : Button = $ColorRect/VBoxContainer/MainMenu
@onready var quit_button: Button  = $ColorRect/VBoxContainer/Button2

func _ready():
	retry_button.pressed.connect(_on_retry)
	quit_button.pressed.connect(_on_quit)
	# Pause the game when this screen appears
	get_tree().paused = true

func _on_retry():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_quit():
	get_tree().paused = false
	get_tree().quit()
