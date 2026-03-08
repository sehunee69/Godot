extends CharacterBody2D

# --- Audio ---
@onready var fx_death: AudioStreamPlayer2D = $fx_death

# --- Stats ---
var speed = 45
var player_chase = false
var player = null
var health = 60
var player_inattack_zone = false
var can_take_damage = true
var can_attack = true
var is_dead = false
var is_attacking = false
var is_stunned = false
var current_animation = ""

# --- Knockback ---
var knockback_force = Vector2.ZERO
const knockback_strength = 130.0
const knockback_decay = 850.0

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────
func _ready():
	add_to_group("enemies")
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)

	var sf = $AnimatedSprite2D.sprite_frames
	# Set fps for each animation
	if sf.has_animation("attack"):
		sf.set_animation_speed("attack", 10.0)
		sf.set_animation_loop("attack", false)
	if sf.has_animation("damaged"):
		sf.set_animation_speed("damaged", 10.0)
		sf.set_animation_loop("damaged", false)
	if sf.has_animation("die"):
		sf.set_animation_speed("die", 10.0)
		sf.set_animation_loop("die", false)
	if sf.has_animation("idle"):
		sf.set_animation_speed("idle", 7.0)
		sf.set_animation_loop("idle", true)
	if sf.has_animation("walking"):
		sf.set_animation_speed("walking", 15.0)
		sf.set_animation_loop("walking", true)

	play_animation("idle")

# ─────────────────────────────────────────────
# MAIN LOOP
# ─────────────────────────────────────────────
func _physics_process(delta):
	if is_dead:
		return

	# Re-acquire player if aggroed but lost reference
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

		if dist > 15 and not player_inattack_zone:
			play_animation("walking")
			velocity = (player.position - position).normalized() * speed
			$AnimatedSprite2D.flip_h = player.position.x > position.x
		elif player_inattack_zone and can_attack:
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
# ATTACK
# ─────────────────────────────────────────────
func _start_attack():
	is_attacking = true
	can_attack = false
	if player != null:
		$AnimatedSprite2D.flip_h = player.position.x > position.x
	play_animation("attack")
	$attack_hit_timer.start()   # fires mid-attack to deal damage

func _on_attack_hit_timer_timeout():
	if is_dead or player == null:
		return
	if player_inattack_zone:
		if player.has_method("take_damage"):
			player.take_damage(10)
		if player.has_method("apply_knockback"):
			player.apply_knockback(global_position)
		print("Slime hit player!")

# ─────────────────────────────────────────────
# ANIMATION FINISHED
# ─────────────────────────────────────────────
func _on_animation_finished():
	var anim = $AnimatedSprite2D.animation

	if anim == "idle" or anim == "walking":
		return

	if anim == "attack":
		is_attacking = false
		can_attack = false
		play_animation("idle")
		$attack_cooldown.start()

	elif anim == "damaged":
		is_stunned = false
		is_attacking = false
		play_animation("idle")
		$attack_cooldown.start()

	elif anim == "die":
		queue_free()

# ─────────────────────────────────────────────
# DETECTION AREA
# ─────────────────────────────────────────────
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player_chase = true

func _on_detection_area_body_exited(body: Node2D) -> void:
	pass   # aggro is permanent once triggered

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
	$attack_hit_timer.stop()
	play_animation("damaged")
	print("Slime took damage! Health:", health)
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
	play_animation("die")

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
	if is_dead and anim != "die":
		return
	current_animation = anim
	$AnimatedSprite2D.play(anim)

func apply_knockback(source_position: Vector2):
	var direction = (position - source_position).normalized()
	knockback_force = direction * knockback_strength

func enemy():
	pass
