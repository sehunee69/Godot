extends Node2D

# --- Audio ---
@onready var fx_axe_hit: AudioStreamPlayer2D = $fx_axeHit
@onready var fx_death: AudioStreamPlayer2D = $fx_death
@onready var laser_sprite: AnimatedSprite2D = $LaserBeam/AnimatedSprite2D
@onready var fx_laser: AudioStreamPlayer2D = $fx_laser

# --- Stats ---
var speed = 40
var player_chase = false
var player = null
var health = 500           # High HP — boss
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
var knockback_strength = 80.0    # Boss is heavier, less knockback
var knockback_decay = 800.0

# --- Projectile ---
var stone_projectile_scene = preload("res://stone_projectile.tscn")
var projectile_count = 0          # tracks how many projectiles fired in 2nd phase
const MAX_PROJECTILES = 3         # shoot 3 times then switch back to phase 1

# --- Laser ---
var laser_target_position = Vector2.ZERO   # locked position when laser charges
var laser_use_count = 0                    # tracks laser uses (triggers phase 3 every 2 uses)

# --- Hibernate ---
var hibernate_heal_amount = 80    # heals this much over 5 seconds
var is_hibernating = false

# ─────────────────────────────────────────────
# BOSS PHASE SYSTEM
# Phase 1 = stone_attack (basic)
# Phase 2 = stone_projectile_attack (shoots 3x)
# Phase 3 = stone_laser_eye_on (used twice before phase 4)
# Phase 4 = stone_hibernate → stone_awake → random attack
# ─────────────────────────────────────────────
enum BossPhase { PHASE_1, PHASE_2, PHASE_3, HIBERNATE }
var current_phase: BossPhase = BossPhase.PHASE_1
var phase_cycle = 0       # counts full cycles to trigger hibernate

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────
var laser_eye_on_frames: int = 0

func _ready():
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	
	var sf = $AnimatedSprite2D.sprite_frames
	if sf.has_animation("stone_laser_eye_on"):
		laser_eye_on_frames = sf.get_frame_count("stone_laser_eye_on")
	sf.set_animation_loop("stone_idle", true)
	# Make sure all these are set to loop OFF
	for anim in ["stone_attack", "stone_damaged", "stone_death", "stone_awake", 
				 "stone_projectile_attack", "stone_projectile_shoot",
				 "stone_laser_eye_on", "stone_laser_eye_off",
				 "stone_laser_beam_on", "stone_laser_beam_off"]:
		if sf.has_animation(anim):
			sf.set_animation_loop(anim, false)
	
	play_animation("stone_idle")
	laser_sprite.animation_finished.connect(_on_laser_animation_finished)
	laser_sprite.visible = false   # hidden by default

	laser_sprite.animation_finished.connect(_on_laser_animation_finished)
	laser_sprite.visible = false

	var laser_sf = laser_sprite.sprite_frames
	if laser_sf.has_animation("stone_laser_beam_on"):
		laser_sf.set_animation_loop("stone_laser_beam_on", false)
		laser_sf.set_animation_speed("stone_laser_beam_on", 5.0)
	if laser_sf.has_animation("stone_laser_beam_off"):
		laser_sf.set_animation_loop("stone_laser_beam_off", false)
		laser_sf.set_animation_speed("stone_laser_beam_off", 5.0)
# ─────────────────────────────────────────────
# MAIN LOOP
# ─────────────────────────────────────────────
func _physics_process(delta):
	if is_dead:
		return

	if knockback_force.length() > 0.1:
		position += knockback_force * delta
		knockback_force = knockback_force.move_toward(Vector2.ZERO, knockback_decay * delta)
		return

	if is_stunned or is_hibernating or is_attacking:
		return

	if player_chase and player != null:
		var dist = position.distance_to(player.position)
		
		# Phase 2 and 3 trigger from anywhere in detection range
		if can_attack and current_phase == BossPhase.PHASE_2:
			_start_phase_attack()
			return
		if can_attack and current_phase == BossPhase.PHASE_3:
			_start_phase_attack()
			return

		# Phase 1 (basic attack) still needs to be close
		if dist > 20:
			play_animation("stone_idle")
			position += (player.position - position).normalized() * speed * delta
			$AnimatedSprite2D.flip_h = player.position.x < position.x
		elif player_inattack_zone and can_attack:
			_start_phase_attack()   # Phase 1 only
	else:
		play_animation("stone_idle")

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
			pass   # handled separately

# ─────────────────────────────────────────────
# PHASE 1 — BASIC ATTACK
# ─────────────────────────────────────────────
func _do_basic_attack():
	is_attacking = true
	can_attack = false
	play_animation("stone_attack")
	# Frame 5 at 8fps = 0.5s
	$attack_hit_timer.start()     # wait time: 0.5s — hits at frame 5

func _on_attack_hit_timer_timeout():
	if is_dead or player == null:
		return
	if player_inattack_zone:
		if player.has_method("take_damage"):
			player.take_damage(10)
		# Apply very light knockback so player stays in hitbox zone
		if player.has_method("apply_knockback"):
			var direction = (player.global_position - global_position).normalized()
			player.knockback_force = direction * 60.0   # ← very small, was 150
		fx_axe_hit.play()
		print("Boss basic attack hit!")

# ─────────────────────────────────────────────
# PHASE 2 — PROJECTILE ATTACK
# ─────────────────────────────────────────────
func _do_projectile_attack():
	is_attacking = true
	can_attack = false
	projectile_count = 0
	play_animation("stone_projectile_attack")
	# Frame 8 at 6fps = 1.167s
	$projectile_timer.start()    # wait time: 1.167s

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
		$attack_cooldown.start()    # ← ADD this so can_attack resets after phase 2

func _fire_stone_projectile():
	if stone_projectile_scene == null:
		push_warning("stone_projectile.tscn not found!")
		return

	var proj = stone_projectile_scene.instantiate()
	if player != null:
		var dir = (player.global_position - global_position).normalized()
		proj.global_position = global_position
		proj.set("direction", dir)    # ← use set() instead of direct property
		proj.rotation = dir.angle()
	get_tree().current_scene.add_child(proj)
	play_animation("stone_projectile_shoot")
	print("Boss fired stone projectile!")

# ─────────────────────────────────────────────
# PHASE 3 — LASER ATTACK
# ─────────────────────────────────────────────
func _do_laser_attack():
	is_attacking = true
	can_attack = false
	if player != null:
		laser_target_position = player.global_position
		var direction = (player.global_position - global_position).normalized()
		$LaserBeam.rotation = direction.angle()
		$AnimatedSprite2D.flip_h = player.global_position.x < global_position.x
	fx_laser.play(9.5)
	play_animation("stone_laser_eye_on")

func _on_laser_charge_timer_timeout():
	if is_dead:
		return
	play_animation("stone_laser_beam_on")
	_check_laser_hit()

func _check_laser_hit():
	if player == null:
		return
	var dist = player.global_position.distance_to(laser_target_position)
	if dist < 50:   # ← increased from 30, gives more generous dodge window
		if player.has_method("take_damage"):
			player.take_damage(40)
		if player.has_method("apply_knockback"):
			player.apply_knockback(global_position)
		print("Boss laser hit player for 40 damage!")
	else:
		print("Player dodged the laser!")

func _on_laser_animation_finished():
	var anim = laser_sprite.animation

	if anim == "stone_laser_beam_on":
		laser_sprite.play("stone_laser_beam_off")

	elif anim == "stone_laser_beam_off":
		laser_sprite.visible = false   # hide beam
		play_animation("stone_laser_eye_off")   # boss body resumes

# ─────────────────────────────────────────────
# HIBERNATE — PHASE 4
# ─────────────────────────────────────────────
func _start_hibernate():
	is_hibernating = true
	is_attacking = false
	can_attack = false
	play_animation("stone_hibernate")
	$hibernate_timer.start()    # wait time: 5.0s
	print("Boss hibernating and regenerating health!")

func _on_hibernate_timer_timeout():
	# Heal over the 5 seconds
	health = min(health + hibernate_heal_amount, max_health)
	print("Boss healed! Health:", health)
	play_animation("stone_awake")
	# after stone_awake anim finishes → handled in _on_animation_finished

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
	# NO can_attack = true here

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
		# Freeze boss body on last frame
		$AnimatedSprite2D.stop()
		if laser_eye_on_frames > 0:
			$AnimatedSprite2D.frame = laser_eye_on_frames - 1
		# Start laser beam on separate sprite
		laser_sprite.visible = true
		laser_sprite.play("stone_laser_beam_on")
		_check_laser_hit()

	elif anim == "stone_laser_beam_on":
		play_animation("stone_laser_beam_off")

	elif anim == "stone_laser_beam_off":
		play_animation("stone_laser_eye_off")

	elif anim == "stone_laser_eye_off":
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
		can_attack = false
		play_animation("stone_idle")
		$attack_cooldown.start()

# ─────────────────────────────────────────────
# AREA DETECTION
# ─────────────────────────────────────────────
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player = body
		player_chase = true

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player_chase = false
		player = null

func _on_enemy_hitbox_body_entered(body: Node2D) -> void:
	print("Stone hitbox entered by:", body.name, " | has player method:", body.has_method("player"))
	if body.has_method("player"):
		player_inattack_zone = true
		print("Player IN stone attack zone!")

func _on_enemy_hitbox_body_exited(body: Node2D) -> void:
	print("Stone hitbox exited by:", body.name)
	if body.has_method("player"):
		player_inattack_zone = false
		print("Player OUT of stone attack zone!")

# ─────────────────────────────────────────────
# TAKE DAMAGE
# ─────────────────────────────────────────────
func take_damage(amount: int):
	print("Boss take_damage called! amount:", amount, " can_take_damage:", can_take_damage, " is_dead:", is_dead)
	if not can_take_damage or is_dead:
		return

	health -= amount
	can_take_damage = false
	print("Boss took damage! Health:", health)

	# Only projectile_shoot gets cancelled by player attack
	# Basic attack and laser continue through damage
	if current_animation == "stone_projectile_shoot":
		is_attacking = false
		print("Boss projectile cancelled by player!")

	is_stunned = true
	play_animation("stone_damaged")
	$take_damage_cooldown.start()

	# Aggro toward player if not already chasing
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
	is_dead = true
	is_stunned = false
	is_hibernating = false
	# Stop all timers
	$attack_cooldown.stop()
	$attack_hit_timer.stop()
	$projectile_timer.stop()
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
