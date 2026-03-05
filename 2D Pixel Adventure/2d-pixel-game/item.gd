extends Control


func _ready():
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	
	if randi() % 2 == 0:
		$TextureRect.texture = load("res://Assets/ironSword.png")
	else:
		$TextureRect.texture = load("res://Assets/battleAxe.png")
