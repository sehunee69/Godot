extends CharacterBody2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 500.0
var damage: int = 25
var lifetime: float = 3.0
var hit_something = false

func _ready():
	collision_layer = 0  # arrow body pushes nothing
	collision_mask = 0 
	#print("=== ARROW SPAWNED ===")
	#print("  Position:", global_position)
	#print("  Direction:", direction)
	#print("  Collision Layer:", collision_layer)
	#print("  Collision Mask:", collision_mask)

func _physics_process(delta):
	#print("ARROW POS: ", global_position, " | PLAYER POS: ", get_tree().get_nodes_in_group("player")[0].global_position)
	if hit_something:
		return
	lifetime -= delta
	if lifetime <= 0:
		#print("Arrow expired — queue_free")
		queue_free()
		return
	velocity = direction * speed
	move_and_slide()
	if is_on_wall():
		#print("Arrow HIT WALL at:", global_position)
		queue_free()
	elif is_on_floor():
		#print("Arrow HIT FLOOR at:", global_position)
		queue_free()
	elif is_on_ceiling():
		#print("Arrow HIT CEILING at:", global_position)
		queue_free()

func _on_area_2d_body_entered(body: Node2D):
	if body == null or not is_instance_valid(body):
		return
	if hit_something:
		return
	#print("--- Arrow Area2D body_entered ---")
	#print("  Body name:", body.name)
	#print("  Body type:", body.get_class())
	#print("  Is in group 'enemies':", body.is_in_group("enemies"))
	#print("  Has take_damage:", body.has_method("take_damage"))
	if hit_something:
		#print("  Already hit something, skipping")
		return
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position)
		#print("  >>> ARROW HIT ENEMY! Dealing", damage, "damage")
		hit_something = true
		queue_free()
	#else:
		#print("  Body is NOT enemy — no damage dealt")
