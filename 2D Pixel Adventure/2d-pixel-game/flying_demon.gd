extends CharacterBody2D

# --- Audio ---
@onready var fx_death: AudioStreamPlayer2D = $fx_death

# --- Stats ---
var speed = 60
var player_chase = false
var player = null
var health = 80
var player_inattack_zone = false
var can_take_damage = true
var can_attack = true
var is_dead = false
var is_attacking = false
var is_stunned = false
var current_animation = ""

# --- Knockback ---
var knockback_force = Vector2.ZERO
const knockback_strength = 120.0
const knockback_decay = 850.0

# --- Fireball ---
var fireball_scene = preload("res://fireball.tscn")

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────
func _ready():
	add_to_group("enemies")
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)

	var sf = $AnimatedSprite2D.sprite_frames
	for anim in ["attack", "damaged", "death"]:
		if sf.has_animation(anim):
			sf.set_animation_loop(anim, false)
	for anim in ["idle", "flying"]:
		if sf.has_animation(anim):
			sf.set_animation_loop(anim, true)

	play_animation("idle")

# ─────────────────────────────────────────────
# MAIN LOOP
# ─────────────────────────────────────────────
func _physics_process(delta):
	if is_dead:
		return

	if player_chase and player == null:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player = players[0]

	# Knockback
	if knockback_force.length() > 0.1:
		knockback_force = knockback_force.move_toward(Vector2.ZERO, knockback_decay * delta)
		velocity = knockback_force
		move_and_slide()
		return

	if is_stunned or is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if player_chase and player != null:
		var dist = position.distance_to(player.position)

		if dist > 80:
			# Fly toward player
			play_animation("flying")
			velocity = (player.position - position).normalized() * speed
			$AnimatedSprite2D.flip_h = player.position.x > position.x
		elif can_attack:
			# In range — do attack
			velocity = Vector2.ZERO
			_start_attack()
		else:
			play_animation("idle")
			if player != null:
				$AnimatedSprite2D.flip_h = player.position.x > position.x
			velocity = Vector2.ZERO
	else:
		play_animation("idle")
		velocity = Vector2.ZERO

	move_and_slide()

# ─────────────────────────────────────────────
# ATTACK — plays animation, fireball spawns after
# ─────────────────────────────────────────────
func _start_attack():
	is_attacking = true
	can_attack = false
	play_animation("attack")
	if player != null:
		$AnimatedSprite2D.flip_h = player.position.x > position.x 
	# Fireball fires in _on_animation_finished when attack anim ends

func _fire_fireball():
	if fireball_scene == null or player == null:
		push_warning("fireball.tscn not found or no player!")
		return

	var fireball = fireball_scene.instantiate()
	print("Fireball spawned at:", global_position)
	var dir = (player.global_position - global_position).normalized()
	fireball.global_position = global_position
	fireball.set("direction", dir)
	fireball.rotation = dir.angle()
	get_tree().current_scene.add_child(fireball)
	print("Flying demon spat fireball!")

# ─────────────────────────────────────────────
# ANIMATION FINISHED
# ─────────────────────────────────────────────
func _on_animation_finished():
	var anim = $AnimatedSprite2D.animation
	
	if anim == "idle" or anim == "flying":   # ← add this guard
		return

	if anim == "attack":
		_fire_fireball()          # ← spawn fireball after attack anim
		is_attacking = false
		can_attack = false
		play_animation("idle")
		$attack_cooldown.start()

	elif anim == "damaged":
		is_stunned = false
		is_attacking = false
		play_animation("idle")
		$attack_cooldown.start()

	elif anim == "death":
		queue_free()

# ─────────────────────────────────────────────
# DETECTION AREA
# ─────────────────────────────────────────────
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player_chase = true

func _on_detection_area_body_exited(body: Node2D) -> void:
	pass

func _on_enemy_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inattack_zone = true

func _on_enemy_hitbox_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inattack_zone = false

# ─────────────────────────────────────────────
# TAKE DAMAGE
# ─────────────────────────────────────────────
func take_damage(amount: int):
	if not can_take_damage or is_dead:
		return

	health -= amount
	can_take_damage = false
	is_stunned = true
	is_attacking = false
	play_animation("damaged")
	print("Flying demon took damage! Health:", health)
	$take_damage_cooldown.start()

	if not player_chase:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player = players[0]
			player_chase = true

	if health <= 0:
		die()

# ─────────────────────────────────────────────
# DEATH
# ─────────────────────────────────────────────
func die():
	is_dead = true
	is_stunned = false
	velocity = Vector2.ZERO
	fx_death.play()
	play_animation("death")

# ─────────────────────────────────────────────
# TIMERS
# ─────────────────────────────────────────────
func _on_take_damage_cooldown_timeout() -> void:
	can_take_damage = true
	is_stunned = false

func _on_attack_cooldown_timeout() -> void:
	can_attack = true

# ─────────────────────────────────────────────
# ANIMATION HELPER
# ─────────────────────────────────────────────
func play_animation(anim: String):
	if current_animation == anim:
		return
	if is_dead and anim != "death":
		return
	current_animation = anim
	$AnimatedSprite2D.play(anim)

func apply_knockback(source_position: Vector2):
	var direction = (position - source_position).normalized()
	knockback_force = direction * knockback_strength

func enemy():
	pass
