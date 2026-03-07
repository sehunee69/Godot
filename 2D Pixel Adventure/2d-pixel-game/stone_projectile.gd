extends CharacterBody2D

@onready var fx_rock_pierce: AudioStreamPlayer2D = $fx_rock_pierce

var direction: Vector2 = Vector2.RIGHT
var speed: float = 120.0
var damage: int = 20
var lifetime: float = 6.0
var is_destroyed = false

func _ready():
	$AnimatedSprite2D.play("stone_projectile_shoot")
	print("=== STONE PROJECTILE SPAWNED ===")
	print("  Position:", global_position)
	print("  Direction:", direction)
	print("  Speed:", speed)
	print("  Collision Layer:", collision_layer)
	print("  Collision Mask:", collision_mask)

func _physics_process(delta):
	if is_destroyed:
		return

	lifetime -= delta
	if lifetime <= 0:
		print("Stone projectile expired — queue_free")
		queue_free()
		return

	velocity = direction * speed
	move_and_slide()

	# Wall collision debug
	if is_on_wall():
		print("Stone projectile HIT WALL at:", global_position)
		_destroy()
	elif is_on_floor():
		print("Stone projectile HIT FLOOR at:", global_position)
		_destroy()
	elif is_on_ceiling():
		print("Stone projectile HIT CEILING at:", global_position)
		_destroy()

# --- Hit player ---
func _on_hitbox_body_entered(body: Node2D):
	print("--- Hitbox body_entered fired ---")
	print("  Body name:", body.name)
	print("  Body type:", body.get_class())
	print("  Is in group 'player':", body.is_in_group("player"))
	print("  Has take_damage:", body.has_method("take_damage"))

	if is_destroyed:
		print("  Projectile already destroyed, skipping")
		return

	if body.is_in_group("player"):
		print("  >>> PLAYER HIT! Dealing", damage, "damage")
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position)
		fx_rock_pierce.play(0)
		$pierce_stop_timer.start()
		_destroy()
	else:
		print("  Body is NOT player — no damage dealt")

# --- Player can attack projectile to cancel it ---
func take_damage(_amount: int):
	print("Stone projectile destroyed by player attack!")
	_destroy()

func _destroy():
	if is_destroyed:
		return
	print("Stone projectile _destroy() called at:", global_position)
	is_destroyed = true

func _on_pierce_stop_timer_timeout():
	fx_rock_pierce.stop()
	queue_free()
