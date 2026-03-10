extends CanvasLayer

@onready var btn_resume : Button = $Resume
@onready var btn_quit   : Button = $Quit

var settings_scene = preload("res://settings_menu.tscn")

func _ready():
	get_tree().paused = true
	btn_resume.pressed.connect(_on_resume)
	btn_quit.pressed.connect(_on_quit)

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):  # Escape key
		_on_resume()

func _on_resume():
	get_tree().paused = false
	queue_free()

func _on_quit():
	get_tree().paused = false
	queue_free()
	get_tree().change_scene_to_file("res://main_menu.tscn")
