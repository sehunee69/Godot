extends CanvasLayer

@onready var retry_button  : Button = $GameOver/Retry
@onready var btn_main_menu : Button = $GameOver/MainMenu
@onready var quit_button   : Button = $GameOver/Quit

var buttons : Array
var current_index : int = 0

func _ready():
	get_tree().paused = true
	retry_button.pressed.connect(_on_retry)
	btn_main_menu.pressed.connect(_on_main_menu)
	quit_button.pressed.connect(_on_quit)

	buttons = [retry_button, btn_main_menu, quit_button]
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

func _on_retry():
	get_tree().paused = false
	queue_free()
	get_tree().reload_current_scene()

func _on_main_menu():
	get_tree().paused = false
	queue_free()
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_quit():
	get_tree().quit()
