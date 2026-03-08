extends CharacterBody2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 150.0
var damage: int = 15
var lifetime: float = 5.0
var is_destroyed = false

func _ready():
	print("Fireball _ready called")
	print("  Sprite2D node:", $Sprite2D)
	print("  Texture:", $Sprite2D.texture)
	$Sprite2D.flip_h = direction.x < 0 
	$Sprite2D.visible = true   # PNG fireball sprite

func _physics_process(delta):
	if is_destroyed:
		return

	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	velocity = direction * speed
	move_and_slide()

	if is_on_wall() or is_on_floor() or is_on_ceiling():
		_destroy()

# --- Hit player ---
func _on_hitbox_body_entered(body: Node2D):
	if is_destroyed:
		return
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position)
		print("Fireball hit player!")
		_destroy()

# --- Player can destroy fireball by attacking it ---
func take_damage(_amount: int):
	print("Fireball destroyed by player!")
	_destroy()

func _destroy():
	if is_destroyed:
		return
	is_destroyed = true
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
			break
	queue_free()
