extends CharacterBody2D

# --- Variables / States ---
@onready var sfx_sword_hit: AudioStreamPlayer2D = $sfx_swordHit
@onready var sfx_special_hit: AudioStreamPlayer2D = $sfx_specialHit


var enemy_inattack_range = false
var health = 100
var is_taking_damage = false
var is_dead = false
var attack_ip = false
var current_dir = "none"
var can_attack = true

var locked_target = null
var nearby_enemies = []
var lock_on_active = false

const SPEED = 100

# --- Ready ---
func _ready():
	play_anim("idle")

# --- Main Loop ---
func _physics_process(delta):
	if not is_dead and not is_taking_damage:
		player_movement()
	if health <= 0 and not is_dead:
		die()
	attack()
	clear_target_if_dead()
	
	if lock_on_active and locked_target != null:
		if locked_target.global_position.x < global_position.x:
			current_dir = "left"
		else:
			current_dir = "right"

# --- Movement ---
func player_movement():
	if Input.is_action_pressed("ui_right"):
		current_dir = "right"
		if not attack_ip:
			play_anim("walking")
		velocity = Vector2(SPEED, 0)
	elif Input.is_action_pressed("ui_left"):
		current_dir = "left"
		if not attack_ip:
			play_anim("walking")
		velocity = Vector2(-SPEED, 0)
	elif Input.is_action_pressed("ui_down"):
		current_dir = "down"
		if not attack_ip:
			play_anim("walking")
		velocity = Vector2(0, SPEED)
	elif Input.is_action_pressed("ui_up"):
		current_dir = "up"
		if not attack_ip:
			play_anim("walking")
		velocity = Vector2(0, -SPEED)
	else:
		velocity = Vector2.ZERO
		if not attack_ip:
			play_anim("idle")
	move_and_slide()

# --- Animations ---
func play_anim(anim: String):
	if is_dead and anim != "death":
		return
	$AnimatedSprite2D.flip_h = (current_dir == "left")
	$AnimatedSprite2D.play(anim)

# --- Damage Handler ---
func take_damage(amount: int):
	if is_taking_damage or is_dead:
		return

	health -= amount
	is_taking_damage = true
	play_anim("damaged")
	print("Player took damage! Health:", health)
	$damage_timer.start()  # ✔️ Timer name must match your actual node

	if health <= 0:
		die()

func _on_damage_timer_timeout():
	is_taking_damage = false

# --- Death Handler ---
func die():
	is_dead = true
	velocity = Vector2.ZERO
	play_anim("death")
	$death_timer.start()

func _on_death_timer_timeout():
	queue_free()

# --- Attack ---
func attack():
	if is_dead or is_taking_damage or not can_attack:
		return
	
	if Input.is_action_just_pressed("lock_on"):
		lock_on()
	
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
	elif Input.is_action_just_pressed("bow"):
		attack_ip = true
		can_attack = false
		_play_attack_anim("bow")
		$bow_attack_timer.start()

func _play_attack_anim(anim_name: String):
	$AnimatedSprite2D.flip_h = (current_dir == "left")
	$AnimatedSprite2D.play(anim_name)
	$deal_attack_timer.start()  # ✔️ This MUST match your actual timer node name

# --- When damage window is open ---
func _on_deal_attack_timer_timeout():
	attack_ip = false

	# Hit detection using player_hitbox
	for body in $player_hitbox.get_overlapping_bodies():
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(20)
			print("Enemy hit!")
		
		if body.has_method("apply_knockback"):
			body.apply_knockback(global_position)

# --- Cooldown Reset ---
func _on_attack_cooldown_timer_timeout():
	can_attack = true

func _on_bow_attack_timer_timeout():
	can_attack = true

func lock_on():
	# Get all enemies in range
	nearby_enemies = []
	for body in $lock_on_area.get_overlapping_bodies():
		if body.is_in_group("enemies") and not body.is_dead:
			nearby_enemies.append(body)
	
	if nearby_enemies.is_empty():
		locked_target = null
		lock_on_active = false
		return
		
	# If no target yet, pick the closest one	
	if locked_target == null or not lock_on_active:
		locked_target = get_closest_enemy()
		lock_on_active = true
	else:
		# Cycle to next enemy in list
		var current_index = nearby_enemies.find(locked_target)
		var next_index = (current_index + 1) % nearby_enemies.size()
		locked_target = nearby_enemies[next_index]

func get_closest_enemy():
	var closest = null
	var closest_dist = INF
	for enemy in nearby_enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy
	return closest
	
func clear_target_if_dead():
	if locked_target != null and locked_target.is_dead:
		locked_target = null
		lock_on_active = false
		lock_on()
		

		
func player():
	pass
