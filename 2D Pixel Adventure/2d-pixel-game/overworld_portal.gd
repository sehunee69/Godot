extends Area2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	anim.play("portal")

func _on_body_entered(body: Node2D) -> void:   # ← was Area2D
	if body.is_in_group("player"):
		body.global_position = Vector2.ZERO   # ← replace with your target position
		print("Player teleported!")
