extends CanvasLayer

@onready var btn_resume   : Button = $VBoxContainer/Resume
@onready var btn_settings : Button = $VBoxContainer/Settings

var settings_scene = preload("res://settings_menu.tscn")

func _ready():
	get_tree().paused = true
	btn_resume.pressed.connect(_on_resume)
	btn_settings.pressed.connect(_on_settings)

func _on_resume():
	get_tree().paused = false
	queue_free()

func _on_settings():
	var settings = settings_scene.instantiate()
	add_child(settings)
