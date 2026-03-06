extends Node2D

# Piercing rock projectile — can be destroyed by player attack
var direction: Vector2 = Vector2.RIGHT
var speed: float = 120.0       # Slow so player can dodge
var damage: int = 20
var lifetime: float = 6.0      # Lives longer so player must deal with it
var hit_something = false
var is_destroyed = false

func _ready():
	$AnimatedSprite2D.play("stone_projectile_shoot")   # your projectile flying anim

func _physics_process(delta):
	if is_destroyed:
		return

	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

# --- Hit player ---
func _on_hitbox_body_entered(body: Node2D):
	if is_destroyed:
		return
	if body.has_method("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position)
		print("Stone projectile hit player!")
		_destroy()

# --- Player can attack projectile to cancel it ---
func take_damage(_amount: int):
	print("Stone projectile destroyed by player!")
	_destroy()

func _destroy():
	is_destroyed = true
	# Play impact anim if you have one
	# $AnimatedSprite2D.play("impact")
	queue_free()
