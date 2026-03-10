extends CanvasLayer

@onready var retry_button : Button = $GameOver/Retry
@onready var btn_main_menu : Button = $GameOver/MainMenu
@onready var quit_button : Button = $GameOver/Quit

func _ready():
	get_tree().paused = true
	retry_button.pressed.connect(_on_retry)
	btn_main_menu.pressed.connect(_on_main_menu)
	quit_button.pressed.connect(_on_quit)

func _on_retry():
	get_tree().paused = false
	queue_free()
	get_tree().reload_current_scene()

func _on_main_menu():
	get_tree().paused = false
	queue_free()
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_quit():
	queue_free()
	get_tree().quit()
