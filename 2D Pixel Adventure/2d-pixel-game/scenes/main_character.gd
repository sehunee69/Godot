extends CharacterBody2D

# --- Audio ---
@onready var sfx_sword_hit: AudioStreamPlayer2D = $sfx_swordHit
@onready var sfx_special_hit: AudioStreamPlayer2D = $sfx_specialHit
@onready var sfx_bow_draw: AudioStreamPlayer2D = $sfx_bowDraw    
@onready var sfx_bow_shoot: AudioStreamPlayer2D = $sfx_bowShoot  
@onready var bow_charge_ui = $BowChargeUI
@onready var bar_fill = $BowChargeUI/BarFill

# --- Status ---
var health_bar_fill = null

# --- Inventory ---
var inventory_scene = preload("res://inventory.tscn")
var inventory_instance = null
var inventory_open = false

# --- Arrow ---
var arrow_scene = preload("res://arrow.tscn")

# --- Knockback ---
var knockback_force = Vector2.ZERO
var knockback_strength = 150.0
var knockback_decay = 600.0

# --- Stats ---
var health = 100
var is_taking_damage = false
var is_dead = false
var attack_ip = false
var current_dir = "right"
var can_attack = true

# --- Lock-on ---
var locked_target = null
var nearby_enemies = []
var lock_on_active = false

# --- Bow State ---
enum BowState { IDLE, DRAWING, HELD }
var bow_state: BowState = BowState.IDLE
var bow_draw_done = false
var bow_total_frames: int = 0

const SPEED = 100
const BOW_SPEED = 5 

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────
func _ready():
	var sf = $AnimatedSprite2D.sprite_frames
	if sf.has_animation("bow_draw"):
		bow_total_frames = sf.get_frame_count("bow_draw")
		sf.set_animation_loop("bow_draw", false)
	if sf.has_animation("bow_shoot"):
		sf.set_animation_loop("bow_shoot", false)
	print("Bow draw frames:", bow_total_frames)

	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	play_anim("idle")
	_hide_bow_charge_ui()
	health_bar_fill = get_tree().current_scene.get_node_or_null("HUD/HealthBarUI/BarFill")
	_update_health_bar()

# ─────────────────────────────────────────────
# MAIN LOOP
# ─────────────────────────────────────────────
func _physics_process(delta):
	# Add this at the top of _physics_process
	if knockback_force.length() > 0.1:
		velocity = knockback_force
		move_and_slide()
		knockback_force = knockback_force.move_toward(Vector2.ZERO, knockback_decay * delta)
		return

	if not is_dead and not is_taking_damage:
		player_movement()

	if health <= 0 and not is_dead:
		die()

	attack()
	_process_bow(delta)
	_process_lock_on()

func apply_knockback(source_position: Vector2):
	var direction = (global_position - source_position).normalized()
	knockback_force = direction * knockback_strength

# ─────────────────────────────────────────────
# HEALTH BAR UI
# ─────────────────────────────────────────────
const MAX_HEALTH = 100
const HEALTH_BAR_WIDTH = 32.0  # ← same width as your BAR_FULL_WIDTH

func _update_health_bar():
	if health_bar_fill == null:
		return
	var progress = clamp(float(health) / float(MAX_HEALTH), 0.0, 1.0)
	health_bar_fill.region_enabled = true
	health_bar_fill.region_rect = Rect2(0, 0, HEALTH_BAR_WIDTH * progress, health_bar_fill.texture.get_height())

# ─────────────────────────────────────────────
# INVENTORY
# ─────────────────────────────────────────────
func _unhandled_input(event):
	if event.is_action_pressed("Inventory"):
		toggle_inventory()

func toggle_inventory():
	if not inventory_open:
		var canvas_layer = CanvasLayer.new()
		canvas_layer.name = "InventoryLayer"
		get_tree().current_scene.add_child(canvas_layer)
		inventory_instance = inventory_scene.instantiate()
		canvas_layer.add_child(inventory_instance)
		await get_tree().process_frame
		var screen_size = get_viewport().get_visible_rect().size
		var inventory_size = inventory_instance.get_rect().size
		inventory_instance.position = (screen_size - inventory_size) / 2
		inventory_open = true
	else:
		if inventory_instance != null:
			var canvas_layer = get_tree().current_scene.get_node_or_null("InventoryLayer")
			if canvas_layer:
				canvas_layer.queue_free()
			inventory_instance = null
		inventory_open = false

# ─────────────────────────────────────────────
# MOVEMENT
# ─────────────────────────────────────────────
func player_movement():
	if attack_ip:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Slow movement while drawing or holding bow
	var current_speed = SPEED
	if bow_state != BowState.IDLE:
		current_speed = BOW_SPEED

	if Input.is_action_pressed("ui_right"):
		current_dir = "right"
		if bow_state == BowState.IDLE:
			play_anim("walking")
		velocity = Vector2(current_speed, 0)
	elif Input.is_action_pressed("ui_left"):
		current_dir = "left"
		if bow_state == BowState.IDLE:
			play_anim("walking")
		velocity = Vector2(-current_speed, 0)
	elif Input.is_action_pressed("ui_down"):
		current_dir = "down"
		if bow_state == BowState.IDLE:
			play_anim("walking")
		velocity = Vector2(0, current_speed)
	elif Input.is_action_pressed("ui_up"):
		current_dir = "up"
		if bow_state == BowState.IDLE:
			play_anim("walking")
		velocity = Vector2(0, -current_speed)
	else:
		velocity = Vector2.ZERO
		if bow_state == BowState.IDLE:
			play_anim("idle")

	move_and_slide()

# ─────────────────────────────────────────────
# ANIMATIONS
# ─────────────────────────────────────────────
func play_anim(anim: String):
	if is_dead and anim != "death":
		return
	if bow_state != BowState.IDLE and anim != "bow_draw" and anim != "bow_shoot" and anim != "damaged" and anim != "death":
		return
	$AnimatedSprite2D.flip_h = (current_dir == "left")
	$AnimatedSprite2D.play(anim)

func _on_animation_finished():
	var anim = $AnimatedSprite2D.animation

	if anim == "bow_draw":
		bow_draw_done = true
		print("Fully charged! R still held:", Input.is_action_pressed("bow"))
		if not Input.is_action_pressed("bow"):
			# Released before anim finished — cancel, no arrow
			_cancel_bow()
			play_anim("idle")
		else:
			# Still holding — freeze on last frame ONCE here only
			bow_state = BowState.HELD
			_hold_bow_last_frame()

	elif anim == "bow_shoot":
		_reset_bow()
		play_anim("idle")

# ─────────────────────────────────────────────
# ATTACK
# ─────────────────────────────────────────────

# Enemy checks this before dealing damage — player wins if mid-attack
func is_player_attacking() -> bool:
	return attack_ip and bow_state == BowState.IDLE

func attack():
	if is_dead or is_taking_damage or not can_attack:
		return

	if Input.is_action_just_pressed("attack"):
		attack_ip = true
		can_attack = false
		_play_attack_anim("attack")
		sfx_sword_hit.play()
		$attack_cooldown_timer.start()

	elif Input.is_action_just_pressed("specialAttack"):
		attack_ip = true
		can_attack = false
		_play_attack_anim("special_attack")
		sfx_special_hit.play()
		$attack_cooldown_timer.start()

func _deal_melee_damage():
	for body in $player_hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(20)
			print("Enemy hit!")
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position)

func _play_attack_anim(anim_name: String):
	$AnimatedSprite2D.flip_h = (current_dir == "left")
	$AnimatedSprite2D.play(anim_name)
	$deal_attack_timer.start()



# ─────────────────────────────────────────────
# BOW SYSTEM
# ─────────────────────────────────────────────
func _process_bow(_delta):
	if is_dead or is_taking_damage:
		return

	# Press R → start draw
	if Input.is_action_just_pressed("bow") and bow_state == BowState.IDLE and can_attack:
		bow_state = BowState.DRAWING
		bow_draw_done = false
		can_attack = false
		attack_ip = false
		$AnimatedSprite2D.speed_scale = 1.0
		play_anim("bow_draw")
		sfx_bow_draw.play()
		_show_bow_charge_ui()
		_update_bow_charge_ui(0.0)

	# Update charge bar while drawing
	if bow_state == BowState.DRAWING:
		var progress = float($AnimatedSprite2D.frame) / float(bow_total_frames - 1)
		_update_bow_charge_ui(progress)

	# Full charge bar while held
	if bow_state == BowState.HELD:
		_update_bow_charge_ui(1.0)
		# ← DO NOT call _hold_bow_last_frame() here, it's already called in _on_animation_finished

	# Release R
	if Input.is_action_just_released("bow"):
		if bow_state == BowState.DRAWING or bow_state == BowState.HELD:
			if bow_draw_done:
				print("Fully charged — firing!")
				_fire_arrow()
				play_anim("bow_shoot")
				_hide_bow_charge_ui()
			else:
				print("Too early — cancelled")
				_cancel_bow() 
				play_anim("idle")

func _hold_bow_last_frame():
	$AnimatedSprite2D.stop()
	if bow_total_frames > 0:
		$AnimatedSprite2D.frame = bow_total_frames - 1

func _reset_bow():
	bow_state = BowState.IDLE
	bow_draw_done = false
	attack_ip = false
	can_attack = false
	sfx_bow_draw.stop()
	_hide_bow_charge_ui()
	$bow_attack_timer.start()

# Called when cancelled (early release or damage) — no cooldown
func _cancel_bow():
	bow_state = BowState.IDLE
	bow_draw_done = false
	attack_ip = false
	can_attack = true             # ← restore immediately, no cooldown
	sfx_bow_draw.stop()
	_hide_bow_charge_ui()
	$bow_attack_timer.stop()      # ← make sure timer isn't running

func _fire_arrow():
	if arrow_scene == null:
		push_error("arrow_scene is null! Check preload path: res://arrow.tscn")
		return

	var arrow = arrow_scene.instantiate()
	if arrow == null:
		push_error("Failed to instantiate arrow!")
		return

	var direction: Vector2
	if lock_on_active and locked_target != null and is_instance_valid(locked_target):
		direction = (locked_target.global_position - global_position).normalized()
	else:
		match current_dir:
			"right": direction = Vector2.RIGHT
			"left":  direction = Vector2.LEFT
			"up":    direction = Vector2.UP
			"down":  direction = Vector2.DOWN
			_:       direction = Vector2.RIGHT

	arrow.global_position = global_position
	arrow.direction = direction
	arrow.rotation = direction.angle()
	get_tree().current_scene.add_child(arrow)
	sfx_bow_shoot.play()
	print("Arrow fired! Direction:", direction)

# ─────────────────────────────────────────────
# HIT WINDOW (melee)
# ─────────────────────────────────────────────
func _on_deal_attack_timer_timeout():
	attack_ip = false   # ← only resets state now, no damage here
	_deal_melee_damage()

# ─────────────────────────────────────────────
# COOLDOWN TIMERS
# ─────────────────────────────────────────────
func _on_attack_cooldown_timer_timeout():
	can_attack = true

func _on_bow_attack_timer_timeout():
	can_attack = true
	attack_ip = false

# ─────────────────────────────────────────────
# DAMAGE & DEATH
# ─────────────────────────────────────────────
func take_damage(amount: int):
	if is_taking_damage or is_dead:
		return
	health -= amount
	_update_health_bar()
	is_taking_damage = true

	if bow_state != BowState.IDLE:
		bow_state = BowState.IDLE
		bow_draw_done = false
		attack_ip = false
		_cancel_bow()
		$AnimatedSprite2D.speed_scale = 1.0
		sfx_bow_draw.stop()
		_hide_bow_charge_ui() 
		$bow_attack_timer.stop()
		can_attack = true   

	play_anim("damaged")
	print("Player took damage! Health:", health)
	$damage_timer.start()

	if health <= 0:
		die()

func _on_damage_timer_timeout():
	is_taking_damage = false

func die():
	is_dead = true
	velocity = Vector2.ZERO
	play_anim("death")
	$death_timer.start()

func _on_death_timer_timeout():
	queue_free()

# ─────────────────────────────────────────────
# LOCK-ON
# ─────────────────────────────────────────────
func _update_lock_on_direction():
	if lock_on_active and locked_target != null and is_instance_valid(locked_target):
		current_dir = "left" if locked_target.global_position.x < global_position.x else "right"
		$AnimatedSprite2D.flip_h = (current_dir == "left")

func lock_on():
	nearby_enemies.clear()
	for body in $lock_on_area.get_overlapping_bodies():
		if body.is_in_group("enemies") and not body.is_dead:
			nearby_enemies.append(body)

	if nearby_enemies.is_empty():
		locked_target = null
		lock_on_active = false
		return

	locked_target = _get_closest_enemy()
	lock_on_active = true

func _get_closest_enemy():
	var closest = null
	var closest_dist = INF
	for enemy in nearby_enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy
	return closest

func clear_target_if_dead():
	pass

func _process_lock_on():
	if Input.is_action_pressed("lock_opponent"):
		if not lock_on_active:
			lock_on()
		_update_lock_on_direction()
	else:
		if lock_on_active:
			locked_target = null
			lock_on_active = false

	if lock_on_active and locked_target != null and locked_target.is_dead:
		locked_target = null
		lock_on_active = false
		lock_on()

# ─────────────────────────────────────────────
# BOW CHARGE UI
# ─────────────────────────────────────────────
const BAR_FULL_WIDTH = 32.0   # ← change to your UI_Flat_BarFill.png pixel width

func _update_bow_charge_ui(progress: float):
	# progress is 0.0 to 1.0
	bar_fill.visible = true
	# Crop the fill sprite from left to right based on progress
	var region = Rect2(0, 0, BAR_FULL_WIDTH * progress, bar_fill.texture.get_height())
	bar_fill.region_enabled = true
	bar_fill.region_rect = region

func _hide_bow_charge_ui():
	bow_charge_ui.visible = false

func _show_bow_charge_ui():
	bow_charge_ui.visible = true

# ─────────────────────────────────────────────
# IDENTIFIERS
# ─────────────────────────────────────────────
func player():
	pass

func _on_area_2d_body_entered(_body):
	pass
