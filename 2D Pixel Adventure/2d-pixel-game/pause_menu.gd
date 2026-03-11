extends CanvasLayer

@onready var btn_resume : Button = $Resume
@onready var btn_quit   : Button = $Quit

var buttons : Array
var current_index : int = 0
var settings_scene = preload("res://settings_menu.tscn")

func _ready():
	get_tree().paused = true
	btn_resume.pressed.connect(_on_resume)
	btn_quit.pressed.connect(_on_quit)

	buttons = [btn_resume, btn_quit]
	buttons[current_index].grab_focus()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_resume()

	elif event.is_action_pressed("ui_down"):
		current_index = (current_index + 1) % buttons.size()
		buttons[current_index].grab_focus()

	elif event.is_action_pressed("ui_up"):
		current_index = (current_index - 1 + buttons.size()) % buttons.size()
		buttons[current_index].grab_focus()

	elif event.is_action_pressed("ui_confirm"):
		buttons[current_index].emit_signal("pressed")

func _on_resume():
	get_tree().paused = false
	queue_free()

func _on_quit():
	get_tree().paused = false
	queue_free()
	get_tree().change_scene_to_file("res://main_menu.tscn")
