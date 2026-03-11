extends Control

@onready var btn_start : Button = $Start
@onready var btn_quit  : Button = $Exit

var buttons : Array
var current_index : int = 0
var settings_scene = preload("res://settings_menu.tscn")

func _ready():
	get_tree().paused = false
	if btn_start:
		btn_start.pressed.connect(_on_start)
	else:
		push_error("Start button not found!")
	if btn_quit:
		btn_quit.pressed.connect(_on_quit)
	else:
		push_error("Quit button not found!")

	buttons = [btn_start, btn_quit]
	buttons[current_index].grab_focus()

func _unhandled_input(event):
	if event.is_action_pressed("ui_down"):
		current_index = (current_index + 1) % buttons.size()
		buttons[current_index].grab_focus()

	elif event.is_action_pressed("ui_up"):
		current_index = (current_index - 1 + buttons.size()) % buttons.size()
		buttons[current_index].grab_focus()

	elif event.is_action_pressed("ui_confirm"):
		buttons[current_index].emit_signal("pressed")

func _on_start():
	var err := get_tree().change_scene_to_file("res://main.tscn")
	if err != OK:
		push_error("Failed to load scene. Error code: %s" % err)

func _on_load():
	print("Load not yet implemented")

func _on_settings():
	var settings = settings_scene.instantiate()
	add_child(settings)

func _on_quit():
	get_tree().quit()
