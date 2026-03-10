extends CharacterBody2D

# --- Audio ---
@onready var sfx_sword_hit: AudioStreamPlayer2D = $sfx_swordHit
@onready var sfx_special_hit: AudioStreamPlayer2D = $sfx_specialHit
@onready var sfx_bow_draw: AudioStreamPlayer2D = $sfx_bowDraw    
@onready var sfx_bow_shoot: AudioStreamPlayer2D = $sfx_bowShoot  
@onready var bow_charge_ui = $BowChargeUI
@onready var bar_fill = $BowChargeUI/BarFill
@onready var fx_hit: AudioStreamPlayer2D = $fx_hit

# --- Attack Animations --- 
# --- Combo ---
@onready var combo_reset_timer = $combo_reset_timer
var combo_count = 0
var combo_timer = 0.0
var combo_window = 0.2

# --- Weapon Sprite ---
@onready var weapon_sprite: AnimatedSprite2D = $WeaponSprite

# --- Dash Timers ---
@onready var dash_timer: Timer = $dash_timer
@onready var dash_cooldown_timer: Timer = $dash_cooldown_timer

# --- Status ---
var health_bar_fill = null
var stamina_bar_fill = null
var stamina_bar_bg = null

# --- Inventory ---
var pause_menu_scene = preload("res://pause_menu.tscn")
var pause_menu_instance = null
var inventory_scene = preload("res://inventory.tscn")
var inventory_instance = null
var inventory_open = false
var canvas_layer = null

# --- Arrow ---
var arrow_scene = preload("res://arrow.tscn")

# --- Knockback ---
var knockback_force = Vector2.ZERO
var knockback_strength = 150.0
var knockback_decay = 600.0

# --- Lunge ---
var lunge_force = Vector2.ZERO
var lunge_strength = 100.0
var lunge_decay = 600.0

# --- Dash ---
const DASH_ANIM_NAME := "dash"
const DASH_FRAMES := 7.0
const DASH_FPS := 20.0
const DASH_DURATION := DASH_FRAMES / DASH_FPS

@export var dash_speed: float = 140.0
@export var dash_cooldown: float = 0.45
@export var dash_stamina_cost: float = 25.0
@export var max_stamina: float = 100.0
@export var stamina_regen_per_sec: float = 18.0
@export var attack_stamina_cost: float = 30.0
@export var special_stamina_cost: float = 20.0

var stamina: float = max_stamina
var is_dashing: bool = false
var dash_dir: Vector2 = Vector2.ZERO

# --- Stats ---
var health = 100
var is_taking_damage = false
var is_dead = false
var attack_ip = false
var current_dir = "right"
var can_attack = false
var is_awakening = true

# --- Lock-on ---
var locked_target = null
var nearby_enemies = []
var lock_on_active = false

# --- Bow State ---
enum BowState { IDLE, DRAWING, HELD }
var bow_state: BowState = BowState.IDLE
var bow_draw_done = false
var bow_total_frames: int = 0

# --- Game State ---
var game_over_scene = preload("res://game_over.tscn")

const SPEED = 70
const BOW_SPEED = 5 

# --- For Picking Up items ---
const PICKUP_RANGE = 64.0

# ─────────────────────────────────────────────
# READY
# ─────────────────────────────────────────────
func _ready():
	weapon_sprite.sprite_frames = preload("res://Assets/animations/sakura blade animation/sakuraBlade1.tres")
	weapon_sprite.visible = false
	weapon_sprite.animation_finished.connect(_on_weapon_animation_finished)

	var sf = $AnimatedSprite2D.sprite_frames
	if sf.has_animation("dash"):
		sf.set_animation_loop("dash", false)
		sf.set_animation_speed("dash", DASH_FPS)
	if sf.has_animation("bow_draw"):
		bow_total_frames = sf.get_frame_count("bow_draw")
		sf.set_animation_loop("bow_draw", false)
	if sf.has_animation("dash"):
		sf.set_animation_loop("dash", false)
		sf.set_animation_speed("dash", DASH_FPS)
	if sf.has_animation("bow_shoot"):
		sf.set_animation_loop("bow_shoot", false)
	if sf.has_animation("awaken"):
		sf.set_animation_loop("awaken", false)
	print("Bow draw frames:", bow_total_frames)

	# Configure and connect dash timers
	dash_timer.wait_time = DASH_DURATION
	dash_timer.one_shot = true
	dash_timer.timeout.connect(_on_dash_timer_timeout)

	dash_cooldown_timer.wait_time = dash_cooldown
	dash_cooldown_timer.one_shot = true
	dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timer_timeout)

	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	play_anim("awaken")
	_hide_bow_charge_ui()

	health_bar_fill = get_tree().current_scene.get_node_or_null("HUD/player_health_bar/HealthBarUI/BarFill")
	_update_health_bar()

	stamina_bar_fill = get_tree().current_scene.get_node_or_null("HUD/player_health_bar/EnergyBarUI/BarFill")
	stamina_bar_bg = get_tree().current_scene.get_node_or_null("HUD/player_health_bar/EnergyBarUI/BarBackground")
	_update_stamina_bar()

func _on_weapon_animation_finished():
	var anim = weapon_sprite.animation
	if anim.begins_with("SakuraBlade_") or anim == "bow_shoot_weapon":
		weapon_sprite.visible = false

func _center_inventory():
	var screen_size = get_viewport().get_visible_rect().size
	inventory_instance.position = screen_size / 2 - inventory_instance.size / 2

# ─────────────────────────────────────────────
# MAIN LOOP
# ─────────────────────────────────────────────
func _physics_process(delta):
	# Knockback overrides everything
	if knockback_force.length() > 0.1:
		velocity = knockback_force
		move_and_slide()
		knockback_force = knockback_force.move_toward(Vector2.ZERO, knockback_decay * delta)
		return

	# Stamina regen
	_update_stamina(delta)

	# Try to start a dash
	if not is_dead and not is_taking_damage:
		_try_start_dash()

	# While dashing — full control handed to dash
	if is_dashing:
		velocity = dash_dir * dash_speed
		move_and_slide()
		attack()
		_process_bow(delta)
		_process_lock_on()
		return

	for item in getNearbyItems():
		item.pick_up_item(self)

	# Lunge forward during attack
	if lunge_force.length() > 0.1:
		velocity = lunge_force
		move_and_slide()
		lunge_force = lunge_force.move_toward(Vector2.ZERO, lunge_decay * delta)
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
# HEALTH & STAMINA BAR UI
# ─────────────────────────────────────────────
const MAX_HEALTH = 100
const HEALTH_BAR_WIDTH = 49
const STAMINA_BAR_WIDTH = 32.0

func _update_health_bar():
	if health_bar_fill == null:
		return
	var progress = clamp(float(health) / float(MAX_HEALTH), 0.0, 1.0)
	health_bar_fill.region_enabled = true
	health_bar_fill.region_rect = Rect2(0, 0, HEALTH_BAR_WIDTH * progress, health_bar_fill.texture.get_height())

func _update_stamina_bar():
	if stamina_bar_fill == null:
		return
	var progress = clamp(stamina / max_stamina, 0.0, 1.0)
	stamina_bar_fill.region_enabled = true
	stamina_bar_fill.region_rect = Rect2(0, 0, STAMINA_BAR_WIDTH * progress, stamina_bar_fill.texture.get_height())

# ─────────────────────────────────────────────
# INVENTORY & PAUSE
# ─────────────────────────────────────────────
func _unhandled_input(event):
	if event.is_action_pressed("Inventory"):
		toggle_inventory()
	if event.is_action_pressed("pause"):
		toggle_pause()

func toggle_pause():
	if pause_menu_instance == null or not is_instance_valid(pause_menu_instance):
		pause_menu_instance = pause_menu_scene.instantiate()
		get_tree().root.add_child(pause_menu_instance)
	else:
		get_tree().paused = false
		pause_menu_instance.queue_free()
		pause_menu_instance = null

func toggle_inventory():
	if inventory_instance == null:
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "InventoryLayer"
		get_tree().root.add_child(canvas_layer)
		inventory_instance = inventory_scene.instantiate()
		canvas_layer.add_child(inventory_instance)
		inventory_instance.add_to_group("inventory")
		await get_tree().process_frame
		var screen_size = get_viewport().get_visible_rect().size
		var inventory_size = inventory_instance.get_rect().size
		inventory_instance.position = (screen_size - inventory_size) / 2

	inventory_open = !inventory_open
	inventory_instance.visible = inventory_open

# ─────────────────────────────────────────────
# MOVEMENT
# ─────────────────────────────────────────────
func player_movement():
	if is_awakening:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_dashing:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if attack_ip:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var current_speed = SPEED
	if bow_state != BowState.IDLE:
		current_speed = BOW_SPEED

	var input_dir = Vector2.ZERO

	if Input.is_action_pressed("ui_right"):
		input_dir.x += 1
		current_dir = "right"
	elif Input.is_action_pressed("ui_left"):
		input_dir.x -= 1
		current_dir = "left"

	if Input.is_action_pressed("ui_down"):
		input_dir.y += 1
		if input_dir.x == 0:
			current_dir = "down"
	if Input.is_action_pressed("ui_up"):
		input_dir.y -= 1
		if input_dir.x == 0:
			current_dir = "up"

	if input_dir != Vector2.ZERO:
		velocity = input_dir.normalized() * current_speed
		if bow_state == BowState.IDLE:
			play_anim("walking")
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
	if attack_ip and anim == "idle" or attack_ip and anim == "walking":
		return
	print("=== play_anim called: ", anim, " | attack_ip: ", attack_ip)
	$AnimatedSprite2D.flip_h = (current_dir == "left")
	$AnimatedSprite2D.play(anim)

func _on_animation_finished():
	var anim = $AnimatedSprite2D.animation

	if anim == "awaken":
		is_awakening = false
		can_attack = true
		play_anim("idle")
		return

	if anim == "bow_draw":
		bow_draw_done = true
		print("Fully charged! R still held:", Input.is_action_pressed("bow"))
		if not Input.is_action_pressed("bow"):
			_cancel_bow()
			play_anim("idle")
		else:
			bow_state = BowState.HELD
			_hold_bow_last_frame()

	elif anim == "bow_shoot":
		_reset_bow()
		play_anim("idle")
	elif anim.begins_with("sakuraBlade_lightAttack"):
		attack_ip = false
		can_attack = true
		if anim == "sakuraBlade_lightAttack3":
			combo_count = 0
			play_anim("idle")
		else:
			combo_reset_timer.start()

func _on_combo_reset_timer_timeout():
	combo_count = 0
	play_anim("idle")

# ─────────────────────────────────────────────
# ATTACK
# ─────────────────────────────────────────────
func is_player_attacking() -> bool:
	return attack_ip and bow_state == BowState.IDLE

func attack():
	if is_dashing:
		return
	if is_dead or is_taking_damage or not can_attack or is_awakening:
		return

	if Input.is_action_just_pressed("attack"):
		if stamina < attack_stamina_cost:   # ← add this check
			_pulse_stamina_bar()
			return
		$combo_reset_timer.stop()
		combo_count += 1
		if combo_count > 3:
			combo_count = 1
		attack_ip = true
		can_attack = false
		stamina -= attack_stamina_cost 
		_play_attack_anim("sakuraBlade_lightAttack" + str(combo_count))
		sfx_sword_hit.play()

	elif Input.is_action_just_pressed("specialAttack"):
		if stamina < special_stamina_cost:  # ← add this check
			_pulse_stamina_bar()
			return
		combo_count = 0
		attack_ip = true
		can_attack = false
		stamina -= special_stamina_cost 
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
		if body.is_in_group("destructibles") and body.has_method("take_damage"):
			body.take_damage()
			print("Destructible hit!")

	for area in $player_hitbox.get_overlapping_areas():
		var parent = area.get_parent()
		if parent.is_in_group("destructibles") and parent.has_method("take_damage"):
			parent.take_damage()

func _play_attack_anim(anim_name: String):
	var current_combo = combo_count
	print("=== PLAYING ATTACK: ", anim_name, " | has anim: ", $AnimatedSprite2D.sprite_frames.has_animation(anim_name))
	$AnimatedSprite2D.flip_h = (current_dir == "left")
	$AnimatedSprite2D.play(anim_name)
	weapon_sprite.flip_h = (current_dir == "left")
	weapon_sprite.visible = true
	weapon_sprite.play("SakuraBlade_" + str(current_combo))
	$attack_lunge_timer.start()
	$deal_attack_timer.start()

	if current_combo == 1:
		await get_tree().process_frame
		weapon_sprite.flip_h = (current_dir == "left")
		weapon_sprite.visible = true
		weapon_sprite.play("SakuraBlade_1")
	else:
		weapon_sprite.flip_h = (current_dir == "left")
		weapon_sprite.visible = true
		weapon_sprite.play("SakuraBlade_" + str(current_combo))

# ─────────────────────────────────────────────
# BOW SYSTEM
# ─────────────────────────────────────────────
func _process_bow(_delta):
	if is_dashing:
		return
	if is_dead or is_taking_damage:
		return

	if Input.is_action_just_pressed("bow") and bow_state == BowState.IDLE and can_attack:
		bow_state = BowState.DRAWING
		bow_draw_done = false
		can_attack = false
		attack_ip = false
		$AnimatedSprite2D.speed_scale = 1.0
		weapon_sprite.flip_h = (current_dir == "left")
		weapon_sprite.visible = true
		weapon_sprite.play("bow_draw_weapon")
		play_anim("bow_draw")
		sfx_bow_draw.play()
		_show_bow_charge_ui()
		_update_bow_charge_ui(0.0)

	if bow_state == BowState.DRAWING:
		var progress = float($AnimatedSprite2D.frame) / float(bow_total_frames - 1)
		_update_bow_charge_ui(progress)

	if bow_state == BowState.HELD:
		_update_bow_charge_ui(1.0)

	if Input.is_action_just_released("bow"):
		if bow_state == BowState.DRAWING or bow_state == BowState.HELD:
			if bow_draw_done:
				print("Fully charged — firing!")
				_fire_arrow()
				play_anim("bow_shoot")
				weapon_sprite.flip_h = (current_dir == "left") 
				weapon_sprite.play("bow_shoot_weapon")
				_hide_bow_charge_ui()
			else:
				print("Too early — cancelled")
				_cancel_bow()
				play_anim("idle")

	if weapon_sprite.visible and weapon_sprite.animation == "SakuraBlade_1":
		match weapon_sprite.frame:
			0, 1:
				weapon_sprite.z_index = -1
			2, 3:
				weapon_sprite.z_index = 1

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

func _cancel_bow():
	weapon_sprite.stop()
	weapon_sprite.visible = false
	bow_state = BowState.IDLE
	bow_draw_done = false
	attack_ip = false
	can_attack = true
	sfx_bow_draw.stop()
	_hide_bow_charge_ui()
	$bow_attack_timer.stop()

func _fire_arrow():
	print("=== FIRE ARROW | lunge_force: ", lunge_force, " | knockback_force: ", knockback_force, " | velocity: ", velocity)
	lunge_force = Vector2.ZERO
	knockback_force = Vector2.ZERO

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
# DASHING
# ─────────────────────────────────────────────
func _dash_pressed() -> bool:
	if InputMap.has_action("dash") and Input.is_action_just_pressed("dash"):
		return true
	return Input.is_key_pressed(KEY_L) or Input.is_joy_button_pressed(0, JOY_BUTTON_B)

func _try_start_dash() -> void:
	if not _dash_pressed():
		return
	if is_dead or is_taking_damage or is_awakening or attack_ip:
		return
	if bow_state != BowState.IDLE:
		return
	if not dash_cooldown_timer.is_stopped():
		return
	if stamina < dash_stamina_cost:
		_pulse_stamina_bar()
		return

	stamina -= dash_stamina_cost
	play_anim(DASH_ANIM_NAME)  # DASH_ANIM_NAME = "dash"
	_update_stamina_bar()
	is_dashing = true
	can_attack = false
	attack_ip = false
	dash_dir = _forward_dir_from_facing()

	# Invincibility frames — change 2 to your enemy hitbox collision layer
	set_collision_mask_value(2, false)

	play_anim(DASH_ANIM_NAME)
	dash_timer.start()
	dash_cooldown_timer.start()

func _on_dash_timer_timeout() -> void:
	is_dashing = false
	set_collision_mask_value(2, true)
	if bow_state == BowState.IDLE and not is_taking_damage and not is_dead:
		can_attack = true
		play_anim("idle")

func _on_dash_cooldown_timer_timeout() -> void:
	pass  # cooldown checked via is_stopped()

func _update_stamina(delta: float) -> void:
	if not is_dashing:
		stamina = min(max_stamina, stamina + stamina_regen_per_sec * delta)
	_update_stamina_bar()

func _pulse_stamina_bar() -> void:
	pass  # hook up a flash tween here if you want visual feedback

func _forward_dir_from_facing() -> Vector2:
	match current_dir:
		"right": return Vector2.RIGHT
		"left":  return Vector2.LEFT
		"up":    return Vector2.UP
		"down":  return Vector2.DOWN
		_:       return Vector2.RIGHT

# ─────────────────────────────────────────────
# HIT WINDOW (melee)
# ─────────────────────────────────────────────
func _on_deal_attack_timer_timeout():
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
	fx_hit.play()
	is_taking_damage = true

	# Cancel dash cleanly on hit
	if is_dashing:
		is_dashing = false
		dash_timer.stop()
		set_collision_mask_value(2, true)

	attack_ip = false
	can_attack = false
	$attack_cooldown_timer.stop()
	$deal_attack_timer.stop()
	$attack_lunge_timer.stop()
	lunge_force = Vector2.ZERO

	if bow_state != BowState.IDLE:
		_cancel_bow()
		$AnimatedSprite2D.speed_scale = 1.0
		sfx_bow_draw.stop()
		_hide_bow_charge_ui()
		$bow_attack_timer.stop()

	$AnimatedSprite2D.stop()
	play_anim("damaged")
	print("Player took damage! Health:", health)
	$damage_timer.start()
	$attack_cooldown_timer.start()

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
	var game_over = game_over_scene.instantiate()
	get_tree().root.add_child(game_over)
	queue_free()

# ─────────────────────────────────────────────
# LOCK-ON
# ─────────────────────────────────────────────
func _update_lock_on_direction():
	if lock_on_active and locked_target != null and is_instance_valid(locked_target):
		current_dir = "left" if locked_target.global_position.x < global_position.x else "right"
		$AnimatedSprite2D.flip_h = (current_dir == "left")
		weapon_sprite.flip_h = (current_dir == "left")

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
const BAR_FULL_WIDTH = 32.0

func _update_bow_charge_ui(progress: float):
	bar_fill.visible = true
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

func _on_attack_lunge_timer_timeout():
	match current_dir:
		"right": lunge_force = Vector2(lunge_strength, 0)
		"left":  lunge_force = Vector2(-lunge_strength, 0)
		"up":    lunge_force = Vector2(0, -lunge_strength)
		"down":  lunge_force = Vector2(0, lunge_strength)

# ─────────────────────────────────────────────
# ITEM PICKUP
# ─────────────────────────────────────────────
func getNearbyItems():
	var nearby = []
	for item in get_tree().get_nodes_in_group("items"):
		if global_position.distance_to(item.global_position) <= PICKUP_RANGE:
			nearby.append(item)
	return nearby
