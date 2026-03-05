extends Node2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 500.0
var damage: int = 25
var lifetime: float = 3.0
var hit_something = false

func _physics_process(delta):
	if hit_something:
		return
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_area_2d_body_entered(body: Node2D):
	if hit_something:
		return
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position)
		print("Arrow hit enemy!")
		hit_something = true
		queue_free()
