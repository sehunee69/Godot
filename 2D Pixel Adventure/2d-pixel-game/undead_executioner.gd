extends CharacterBody2D

# --- Audio ---
@onready var fx_death: AudioStreamPlayer2D = $fx_death
@onready var fx_attack: AudioStreamPlayer2D = $fx_attack
@onready var fx_skill: AudioStreamPlayer2D = $fx_skill
@onready var fx_summon: AudioStreamPlayer2D = $fx_summon

# --- Stats ---
var speed = 35
var player_chase = false
var player = null
var health = 1000
var max_health = 1000
var player_inattack_zone = false
var can_take_damage = true
var can_attack = true
var is_dead = false
var is_stunned = false
var is_attacking = false
var is_summoning = false
var is_invulnerable = false
var current_animation = ""

# --- Knockback ---
var knockback_force = Vector2.ZERO
var knockback_strength = 50.0   # Boss is heavy, less knockback
var knockback_decay = 800.0

# --- Summon ---
var summon_scene = preload("res://summoned_spirits.tscn")

# --- HUD ---
var hud = null

# ─────────────────────────────────────────────
# BOSS PHASE SYSTEM
# Phase 1 = attack only           (1000 → 700hp)
# Phase 2 = attack + skill        (700 → 300hp)
# Phase 3 = attack + skill + summon (300 → 0hp)
# ─────────────────────────────────────────────
enum BossPhase { PHASE_1, PHASE_2, PHASE_3 }
var current_phase: BossPhase = BossPhase.PHASE_1

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────
func _ready():
	add_to_group("enemies")
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)

	hud = get_tree().current_scene.get_node_or_null("HUD")

	var sf = $AnimatedSprite2D.sprite_frames
	sf.set_animation_loop("idle", true)
	for anim in ["attack", "skill", "summons", "death"]:
		if sf.has_animation(anim):
			sf.set_animation_loop(anim, false)

	# Set fps
	if sf.has_animation("attack"):  sf.set_animation_speed("attack", 8.0)
	if sf.has_animation("idle"):    sf.set_animation_speed("idle", 8.0)
	if sf.has_animation("summons"): sf.set_animation_speed("summons", 6.0)
	if sf.has_animation("skill"):   sf.set_animation_speed("skill", 8.0)
	if sf.has_animation("death"):   sf.set_animation_speed("death", 8.0)

	play_animation("idle")

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

	if is_stunned or is_attacking or is_summoning:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if player_chase and player != null:
		var dist = position.distance_to(player.position)

		if is_stunned or is_attacking or is_summoning:
			velocity = Vector2.ZERO
			move_and_slide()
			return

		if dist > 30:
			play_animation("idle")
			velocity = (player.position - position).normalized() * speed
			$AnimatedSprite2D.flip_h = player.position.x < position.x
		elif can_attack:
			velocity = Vector2.ZERO
			_choose_attack()
		else:
			play_animation("idle")
			$AnimatedSprite2D.flip_h = player.position.x < position.x
			velocity = Vector2.ZERO
	else:
		play_animation("idle")
		velocity = Vector2.ZERO

	move_and_slide()

# ─────────────────────────────────────────────
# PHASE CHECK — called after every hit
# ─────────────────────────────────────────────
func _check_phase():
	if health <= 300 and current_phase != BossPhase.PHASE_3:
		current_phase = BossPhase.PHASE_3
		print("Undead Executioner entering Phase 3!")
	elif health <= 700 and current_phase == BossPhase.PHASE_1:
		current_phase = BossPhase.PHASE_2
		print("Undead Executioner entering Phase 2!")

# ─────────────────────────────────────────────
# ATTACK SELECTOR
# ─────────────────────────────────────────────
func _choose_attack():
	if not can_attack or is_attacking or is_summoning:
		return

	match current_phase:
		BossPhase.PHASE_1:
			_do_attack()

		BossPhase.PHASE_2:
			# Random: attack or skill
			if randi() % 2 == 0:
				_do_attack()
			else:
				_do_skill()

		BossPhase.PHASE_3:
			# Random: attack, skill, or summon
			var roll = randi() % 3
			if roll == 0:
				_do_attack()
			elif roll == 1:
				_do_skill()
			else:
				_do_summon()

# ─────────────────────────────────────────────
# ATTACK — 2-hit swing, 5 damage
# ─────────────────────────────────────────────
func _do_attack():
	is_attacking = true
	can_attack = false
	is_invulnerable = true
	if player != null:
		$AnimatedSprite2D.flip_h = player.position.x < position.x
	play_animation("attack")
	$attack_hit_timer.start()   # time this to hit frame ~7 of 13 at 8fps = ~0.875s
	$attack_hit_timer_2.start()

func _on_attack_hit_timer_timeout():
	if is_dead or player == null:
		return
	if position.distance_to(player.position) < 40:
		if player.has_method("take_damage"):
			player.take_damage(5)
		if player.has_method("apply_knockback"):
			var dir = (player.global_position - global_position).normalized()
			player.knockback_force = dir * 80.0
		fx_attack.play()
		print("Executioner attack hit player!")

# ─────────────────────────────────────────────
# SKILL — 10 damage
# ─────────────────────────────────────────────
func _do_skill():
	is_attacking = true
	can_attack = false
	if player != null:
		$AnimatedSprite2D.flip_h = player.position.x < position.x
	play_animation("skill")
	$skill_hit_timer.start()   # time this to hit frame ~8 of 12 at 8fps = ~1.0s

func _on_skill_hit_timer_timeout():
	if is_dead or player == null:
		return
	if position.distance_to(player.position) < 40:
		if player.has_method("take_damage"):
			player.take_damage(10)
		if player.has_method("apply_knockback"):
			var dir = (player.global_position - global_position).normalized()
			player.knockback_force = dir * 120.0
		fx_skill.play()
		print("Executioner skill hit player!")

# ─────────────────────────────────────────────
# SUMMON — spawns spirit that deals 2 damage
# ─────────────────────────────────────────────
func _do_summon():
	is_summoning = true
	can_attack = false
	if player != null:
		$AnimatedSprite2D.flip_h = player.position.x < position.x
	play_animation("summons")
	fx_summon.play()
	# Spirit spawns in _on_animation_finished when summons anim ends

func _spawn_spirit():
	if summon_scene == null or player == null:
		push_warning("summoned_spirit.tscn not found or no player!")
		return
	var spirit = summon_scene.instantiate()
	# Spawn near boss, offset slightly so it doesn't overlap
	spirit.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	get_tree().current_scene.add_child(spirit)
	print("Executioner summoned a spirit!")

# ─────────────────────────────────────────────
# ANIMATION FINISHED
# ─────────────────────────────────────────────
func _on_animation_finished():
	var anim = $AnimatedSprite2D.animation

	if anim == "idle":
		return

	if anim == "attack":
		is_attacking = false
		is_invulnerable = false
		can_attack = false
		play_animation("idle")
		$attack_cooldown.start()

	elif anim == "skill":
		is_attacking = false
		is_invulnerable = false
		can_attack = false
		play_animation("idle")
		$attack_cooldown.start()

	elif anim == "summons":
		_spawn_spirit()
		is_summoning = false
		can_attack = false
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
		if hud:
			hud.show_boss_bar("Undead Executioner")
			hud.update_boss_health(health, max_health)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player_chase = false
		player = null
		if hud:
			hud.hide_boss_bar()

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
	if not can_take_damage or is_dead or is_invulnerable:
		return

	health -= amount
	_check_phase()

	if hud:
		hud.update_boss_health(health, max_health)

	can_take_damage = false
	is_attacking = false
	is_summoning = false  
	$attack_hit_timer.stop() 
	$attack_hit_timer_2.stop()
	$skill_hit_timer.stop()
	print("Executioner took damage! Health:", health)
	$take_damage_cooldown.start()
	$attack_cooldown.start()

	if not player_chase:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player = players[0]
			player_chase = true

	if health <= 0:
		die()
		fx_death.play()

# ─────────────────────────────────────────────
# DEATH
# ─────────────────────────────────────────────
func die():
	if hud:
		hud.hide_boss_bar()
	is_dead = true
	is_stunned = false
	is_summoning = false
	velocity = Vector2.ZERO
	$attack_cooldown.stop()
	$attack_hit_timer.stop()
	$skill_hit_timer.stop()
	$attack_hit_timer_2.stop()
	play_animation("death")
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
	if is_dead and anim != "death":
		return
	current_animation = anim
	$AnimatedSprite2D.play(anim)

func apply_knockback(source_position: Vector2):
	var direction = (position - source_position).normalized()
	knockback_force = direction * knockback_strength

func enemy():
	pass


func _on_attack_hit_timer_2_timeout():
	if is_dead or player == null:
		return
	if position.distance_to(player.position) < 40:
		if player.has_method("take_damage"):
			player.take_damage(5)
		if player.has_method("apply_knockback"):
			var dir = (player.global_position - global_position).normalized()
			player.knockback_force = dir * 80.0
		fx_attack.play()
		print("Executioner second swing hit player!")
