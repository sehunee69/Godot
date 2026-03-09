extends CharacterBody2D

# --- Stats ---
var speed = 50
var player = null
var damage = 2
var can_damage = true
var is_dead = false
var current_animation = ""

# --- Knockback ---
var knockback_force = Vector2.ZERO
const knockback_strength = 60.0
const knockback_decay = 850.0

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────
func _ready():
	add_to_group("enemies")
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)

	var sf = $AnimatedSprite2D.sprite_frames
	if sf.has_animation("summon_appears"):
		sf.set_animation_loop("summon_appears", false)
		sf.set_animation_speed("summon_appears", 6.0)
	if sf.has_animation("summon_idle"):
		sf.set_animation_loop("summon_idle", true)
		sf.set_animation_speed("summon_idle", 6.0)
	if sf.has_animation("summons_death"):
		sf.set_animation_loop("summons_death", false)
		sf.set_animation_speed("summons_death", 6.0)

	# Find player
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player = players[0]

	play_animation("summon_appears")

# ─────────────────────────────────────────────
# MAIN LOOP
# ─────────────────────────────────────────────
func _physics_process(delta):
	if is_dead:
		return

	# Knockback
	if knockback_force.length() > 0.1:
		knockback_force = knockback_force.move_toward(Vector2.ZERO, knockback_decay * delta)
		velocity = knockback_force
		move_and_slide()
		return

	# Only chase after appearing anim finishes
	if current_animation == "summon_appears":
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if player != null and is_instance_valid(player):
		velocity = (player.position - position).normalized() * speed
		$AnimatedSprite2D.flip_h = player.position.x < position.x
	else:
		velocity = Vector2.ZERO

	move_and_slide()

# ─────────────────────────────────────────────
# ANIMATION FINISHED
# ─────────────────────────────────────────────
func _on_animation_finished():
	var anim = $AnimatedSprite2D.animation

	if anim == "summon_appears":
		play_animation("summon_idle")

	elif anim == "summons_death":
		queue_free()

# ─────────────────────────────────────────────
# TOUCH DAMAGE — spirit damages player on contact
# ─────────────────────────────────────────────
func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dead:
		return
	if body.is_in_group("player") and can_damage:
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position)
		can_damage = false
		$damage_cooldown.start()
		print("Spirit touched player! Dealt", damage, "damage")
		die()

# ─────────────────────────────────────────────
# TAKE DAMAGE — player can kill spirit
# ─────────────────────────────────────────────
func take_damage(_amount: int):
	if is_dead:
		return
	die()

func die():
	is_dead = true
	velocity = Vector2.ZERO
	play_animation("summons_death")

# ─────────────────────────────────────────────
# TIMERS
# ─────────────────────────────────────────────
func _on_damage_cooldown_timeout() -> void:
	can_damage = true

func _on_death_timer_timeout() -> void:
	queue_free()

# ─────────────────────────────────────────────
# ANIMATION HELPER
# ─────────────────────────────────────────────
func play_animation(anim: String):
	if current_animation == anim:
		return
	if is_dead and anim != "summons_death":
		return
	current_animation = anim
	$AnimatedSprite2D.play(anim)

func apply_knockback(source_position: Vector2):
	var direction = (position - source_position).normalized()
	knockback_force = direction * knockback_strength

func enemy():
	pass
