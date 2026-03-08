extends Control

var item_name
@onready var texture_rect = $TextureRect

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_random_item()

func set_random_item():
	var rand_val = randi() % 3
	if rand_val == 0:
		item_name = "Sakura Blade"
	elif rand_val == 1:
		item_name = "Conquerers Fury"
	else:
		item_name = "Battle Axe"
	
	set_texture()

func set_texture():
	var path = "res://Assets/weapons/" + item_name + ".png"
	if ResourceLoader.exists(path):
		texture_rect.texture = load(path)
	else:
		print("Texture not found: ", path)
	
	texture_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED

func set_item(name: String):
	item_name = name
	set_texture()
