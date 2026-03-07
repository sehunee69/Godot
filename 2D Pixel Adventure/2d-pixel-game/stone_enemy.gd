extends CharacterBody2D

# --- Audio ---
@onready var fx_stone_punch: AudioStreamPlayer2D = $fx_stone_punch
@onready var fx_rock_merge: AudioStreamPlayer2D = $fx_rock_merge
@onready var fx_death: AudioStreamPlayer2D = $fx_death
@onready var laser_sprite: AnimatedSprite2D = $LaserBeam/AnimatedSprite2D
@onready var fx_laser: AudioStreamPlayer2D = $fx_laser
@onready var laser_hitbox: Area2D = $LaserBeam/LaserHitbox

# --- Stats ---
var speed = 40
var player_chase = false
var player = null
var health = 500
var max_health = 500
var player_inattack_zone = false
var can_take_damage = true
var can_attack = true
var is_dead = false
var is_stunned = false
var is_attacking = false
var current_animation = ""

# --- Knockback ---
var knockback_force = Vector2.ZERO
var knockback_strength = 80.0
var knockback_decay = 800.0

# --- Projectile ---
var stone_projectile_scene = preload("res://stone_projectile.tscn")
var projectile_count = 0
const MAX_PROJECTILES = 3

# --- Laser ---
var laser_target_position = Vector2.ZERO
var laser_use_count = 0
var laser_tracking = false
var laser_rotate_speed = 1.2
var laser_damage_cooldown = false

# --- Hibernate ---
var hibernate_heal_amount = 80
var is_hibernating = false

# ─────────────────────────────────────────────
# BOSS PHASE SYSTEM
# ─────────────────────────────────────────────
enum BossPhase { PHASE_1, PHASE_2, PHASE_3, HIBERNATE }
var current_phase: BossPhase = BossPhase.PHASE_1
var phase_cycle = 0

var laser_eye_on_frames: int = 0

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────
func _ready():
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	laser_hitbox.monitoring = false
	laser_hitbox.monitorable = true

	var sf = $AnimatedSprite2D.sprite_frames
	if sf.has_animation("stone_laser_eye_on"):
		laser_eye_on_frames = sf.get_frame_count("stone_laser_eye_on")
	sf.set_animation_loop("stone_idle", true)
	for anim in ["stone_attack", "stone_damaged", "stone_death", "stone_awake",
				 "stone_projectile_attack", "stone_projectile_shoot",
				 "stone_laser_eye_on", "stone_laser_eye_off",
				 "stone_laser_beam_on", "stone_laser_beam_off"]:
		if sf.has_animation(anim):
			sf.set_animation_loop(anim, false)

	play_animation("stone_idle")
	laser_sprite.animation_finished.connect(_on_laser_animation_finished)
	laser_sprite.visible = false

	var laser_sf = laser_sprite.sprite_frames
	if laser_sf.has_animation("stone_laser_beam_on"):
		laser_sf.set_animation_loop("stone_laser_beam_on", true)
		laser_sf.set_animation_speed("stone_laser_beam_on", 12.0)
	if laser_sf.has_animation("stone_laser_beam_off"):
		laser_sf.set_animation_loop("stone_laser_beam_off", false)
		laser_sf.set_animation_speed("stone_laser_beam_off", 12.0)

# ─────────────────────────────────────────────
# MAIN LOOP
# ─────────────────────────────────────────────
func _physics_process(delta):
	if is_dead:
		return

	# Laser beam tracking
	if laser_tracking and player != null:
		var target_angle = (player.global_position - global_position).angle()
		var current_angle = $LaserBeam.rotation
		$LaserBeam.rotation = lerp_angle(current_angle, target_angle, laser_rotate_speed * delta)
		$AnimatedSprite2D.flip_h = player.global_position.x < global_position.x

	# Laser continuous damage
	if laser_hitbox.monitoring and not laser_damage_cooldown:
		var bodies = laser_hitbox.get_overlapping_bodies()
		for body in bodies:
			if body.has_method("take_damage"):
				body.take_damage(5)
				laser_damage_cooldown = true
				$laser_damage_tick.start()
				break

	# Knockback
	if knockback_force.length() > 0.1:
		knockback_force = knockback_force.move_toward(Vector2.ZERO, knockback_decay * delta)
		velocity = knockback_force
		move_and_slide()
		return

	if is_stunned or is_hibernating or is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if player_chase and player != null:
		var dist = position.distance_to(player.position)

		# Phase 2 and 3 — back away first, then attack once far enough
		if current_phase == BossPhase.PHASE_2 or current_phase == BossPhase.PHASE_3:
			if dist < 120:
				play_animation("stone_idle")
				var direction = -(player.position - position).normalized()
				velocity = direction * speed
				$AnimatedSprite2D.flip_h = player.position.x < position.x
				if velocity.length() > 0 and get_last_motion().length() < 0.5:
					velocity = Vector2.ZERO
					if can_attack:
						_start_phase_attack()
			elif can_attack:
				velocity = Vector2.ZERO
				_start_phase_attack()
			move_and_slide()
			return

		# Phase 1 — chase and attack close range
		if dist > 14 and not player_inattack_zone:
			play_animation("stone_idle")
			velocity = (player.position - position).normalized() * speed
			$AnimatedSprite2D.flip_h = player.position.x < position.x
		elif player_inattack_zone and can_attack:
			velocity = Vector2.ZERO
			_start_phase_attack()
		else:
			velocity = Vector2.ZERO
	else:
		play_animation("stone_idle")
		velocity = Vector2.ZERO

	move_and_slide()

# ─────────────────────────────────────────────
# PHASE ATTACK SELECTOR
# ─────────────────────────────────────────────
func _start_phase_attack():
	if not can_attack or is_attacking:
		return

	match current_phase:
		BossPhase.PHASE_1:
			_do_basic_attack()
		BossPhase.PHASE_2:
			_do_projectile_attack()
		BossPhase.PHASE_3:
			_do_laser_attack()
		BossPhase.HIBERNATE:
			pass

# ─────────────────────────────────────────────
# PHASE 1 — BASIC ATTACK
# ─────────────────────────────────────────────
func _do_basic_attack():
	is_attacking = true
	can_attack = false
	play_animation("stone_attack")
	$attack_hit_timer.start()

func _on_attack_hit_timer_timeout():
	if is_dead or player == null:
		return
	if player_inattack_zone:
		if player.has_method("take_damage"):
			player.take_damage(10)
		if player.has_method("apply_knockback"):
			var direction = (player.global_position - global_position).normalized()
			player.knockback_force = direction * 60.0
		fx_stone_punch.play()
		print("Boss basic attack hit!")

# ─────────────────────────────────────────────
# PHASE 2 — PROJECTILE ATTACK
# ─────────────────────────────────────────────
func _do_projectile_attack():
	is_attacking = true
	can_attack = false
	projectile_count = 0
	play_animation("stone_projectile_attack")
	$projectile_timer.start()

func _on_projectile_timer_timeout():
	if is_dead or player == null:
		return
	_fire_stone_projectile()
	projectile_count += 1

	if projectile_count < MAX_PROJECTILES:
		play_animation("stone_projectile_attack")
		$projectile_timer.start()
	else:
		projectile_count = 0
		is_attacking = false
		can_attack = false
		_advance_phase()
		$attack_cooldown.start()

func _fire_stone_projectile():
	if stone_projectile_scene == null:
		push_warning("stone_projectile.tscn not found!")
		return

	var proj = stone_projectile_scene.instantiate()
	if player != null:
		var dir = (player.global_position - global_position).normalized()
		proj.global_position = global_position
		proj.set("direction", dir)
		proj.rotation = dir.angle()
	get_tree().current_scene.add_child(proj)
	play_animation("stone_projectile_shoot")
	print("Boss fired stone projectile!")

# ─────────────────────────────────────────────
# PHASE 3 — LASER ATTACK
# ─────────────────────────────────────────────
func _do_laser_attack():
	if is_attacking:   # ← already mid-charge, don't restart
		return

	is_attacking = true
	can_attack = false
	laser_tracking = false
	if player != null:
		var direction = (player.global_position - global_position).normalized()
		$LaserBeam.rotation = direction.angle()
		$AnimatedSprite2D.flip_h = player.global_position.x < global_position.x
	play_animation("stone_laser_eye_on")
	$laser_beam_start_timer.start()

func _on_laser_animation_finished():
	var anim = laser_sprite.animation

	if anim == "stone_laser_beam_on":
		laser_sprite.play("stone_laser_beam_off")

	if anim == "stone_laser_beam_off":
		laser_sprite.visible = false
		play_animation("stone_laser_eye_off")

# ─────────────────────────────────────────────
# HIBERNATE — PHASE 4
# ─────────────────────────────────────────────
func _start_hibernate():
	fx_rock_merge.play(0)
	$merge_stop_timer.start()
	is_hibernating = true
	is_attacking = false
	can_attack = false
	play_animation("stone_hibernate")
	$hibernate_timer.start()
	print("Boss hibernating and regenerating health!")

func _on_hibernate_timer_timeout():
	health = min(health + hibernate_heal_amount, max_health)
	print("Boss healed! Health:", health)
	play_animation("stone_awake")

# ─────────────────────────────────────────────
# PHASE ADVANCEMENT
# ─────────────────────────────────────────────
func _advance_phase():
	phase_cycle += 1
	is_attacking = false

	match current_phase:
		BossPhase.PHASE_1:
			current_phase = BossPhase.PHASE_2
			print("Boss advancing to Phase 2 (projectile)")

		BossPhase.PHASE_2:
			if phase_cycle >= 4:
				phase_cycle = 0
				_start_hibernate()
				return
			else:
				current_phase = BossPhase.PHASE_1
				print("Boss back to Phase 1 (basic attack)")

		BossPhase.PHASE_3:
			laser_use_count += 1
			print("Laser use count:", laser_use_count)
			if laser_use_count >= 2:
				laser_use_count = 0
				_start_hibernate()
				return
			else:
				current_phase = BossPhase.PHASE_1
				print("Boss back to Phase 1 after laser")

		BossPhase.HIBERNATE:
			current_phase = BossPhase.PHASE_3
			print("Boss awake — Phase 3 (laser)")

# ─────────────────────────────────────────────
# ANIMATION FINISHED
# ─────────────────────────────────────────────
func _on_animation_finished():
	var anim = $AnimatedSprite2D.animation

	if anim == "stone_idle":
		return

	if anim == "stone_attack":
		is_attacking = false
		can_attack = false
		play_animation("stone_idle")
		_advance_phase()
		$attack_cooldown.start()

	elif anim == "stone_projectile_shoot":
		pass

	elif anim == "stone_laser_eye_on":
		$AnimatedSprite2D.stop()
		if laser_eye_on_frames > 0:
			$AnimatedSprite2D.frame = laser_eye_on_frames - 1

	elif anim == "stone_laser_eye_off":
		$laser_beam_timer.stop()
		is_attacking = false
		can_attack = false
		play_animation("stone_idle")
		_advance_phase()
		$attack_cooldown.start()

	elif anim == "stone_awake":
		is_hibernating = false
		is_attacking = false
		can_attack = false
		current_phase = BossPhase.PHASE_3
		play_animation("stone_idle")
		$attack_cooldown.start()
		print("Boss awake! Going to Phase 3 (laser)")

	elif anim == "stone_damaged":
		is_stunned = false
		is_attacking = false
		can_attack = false
		play_animation("stone_idle")
		$attack_cooldown.start()

# ─────────────────────────────────────────────
# AREA DETECTION
# ─────────────────────────────────────────────
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player_chase = true

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player_chase = false
		player = null

func _on_enemy_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inattack_zone = true
		print("Player IN stone attack zone!")

func _on_enemy_hitbox_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inattack_zone = false
		print("Player OUT of stone attack zone!")

# ─────────────────────────────────────────────
# TAKE DAMAGE
# ─────────────────────────────────────────────
func take_damage(amount: int):
	if not can_take_damage or is_dead:
		return

	if current_animation == "stone_laser_eye_on":
		fx_laser.stop()
		$laser_beam_start_timer.stop()
		$laser_damage_enable_timer.stop()
		laser_hitbox.monitoring = false
		is_attacking = false

	health -= amount
	can_take_damage = false
	print("Boss took damage! Health:", health)

	if current_animation == "stone_projectile_shoot":
		is_attacking = false
		print("Boss projectile cancelled by player!")

	if is_hibernating:
		$take_damage_cooldown.start()
		if health <= 0:
			die()
			fx_death.play()
		return

	is_stunned = true
	current_animation = ""
	play_animation("stone_damaged")
	$take_damage_cooldown.start()

	if not player_chase:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player = players[0]
			player_chase = true
			print("Boss aggroed from damage!")

	if health <= 0:
		die()
		fx_death.play()

# ─────────────────────────────────────────────
# DEATH
# ─────────────────────────────────────────────
func die():
	laser_tracking = false
	laser_hitbox.monitoring = false
	laser_sprite.visible = false
	is_dead = true
	is_stunned = false
	is_hibernating = false
	fx_rock_merge.stop()
	$merge_stop_timer.stop()
	$attack_cooldown.stop()
	$attack_hit_timer.stop()
	$projectile_timer.stop()
	$laser_beam_start_timer.stop()
	$laser_damage_enable_timer.stop()
	$laser_charge_timer.stop()
	$hibernate_timer.stop()
	play_animation("stone_death")
	$death_timer.start()

# ─────────────────────────────────────────────
# TIMERS
# ─────────────────────────────────────────────
func _on_take_damage_cooldown_timeout() -> void:
	can_take_damage = true
	is_stunned = false

func _on_attack_cooldown_timeout() -> void:
	can_attack = true

func _on_death_timer_timeout() -> void:
	queue_free()

func _on_laser_beam_timer_timeout():
	laser_tracking = false
	laser_hitbox.monitoring = false
	laser_sprite.stop()
	laser_sprite.play("stone_laser_beam_off")

# ─────────────────────────────────────────────
# ANIMATION HELPER
# ─────────────────────────────────────────────
func play_animation(anim: String):
	if current_animation == anim:
		return
	if is_dead and anim != "stone_death":
		return
	current_animation = anim
	$AnimatedSprite2D.play(anim)

func apply_knockback(source_position: Vector2):
	var direction = (position - source_position).normalized()
	knockback_force = direction * knockback_strength

func enemy():
	pass

func _on_laser_damage_tick_timeout():
	laser_damage_cooldown = false

func _on_laser_beam_start_timer_timeout():
	if is_dead:
		return
	laser_sprite.visible = true
	laser_sprite.play("stone_laser_beam_on")   # starts from frame 0 (charge frames)
	laser_tracking = true
	fx_laser.play(9.5)
	$laser_beam_timer.start()                  # existing beam duration timer
	$laser_damage_enable_timer.start()         # damage waits for frame 9

func _on_laser_damage_enable_timer_timeout():
	if is_dead or not laser_sprite.visible:
		return
	laser_hitbox.monitoring = true   # ← now synced with actual beam frame


func _on_merge_stop_timer_timeout():
	fx_rock_merge.stop()
