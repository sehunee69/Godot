extends CharacterBody2D

@onready var fx_axe_hit: AudioStreamPlayer2D = $fx_axeHit
@onready var fx_death: AudioStreamPlayer2D = $fx_death
@onready var fx_goblin_scream: AudioStreamPlayer2D = $fx_goblin_scream

var speed = 50
var player_chase = false
var player = null
var health = 100
var player_inattack_zone = false
var can_take_damage = true
var can_attack = true
var is_dead = false
var is_attacking = false
var is_stunned = false

var knockback_force = Vector2.ZERO
const knockback_strength = 150.0
const knockback_decay = 850.0
var current_animation = ""

func _ready():
	play_animation("idle")

func _physics_process(delta):
	if is_dead:
		return

	# Knockback
	if knockback_force.length() > 0.1:
		knockback_force = knockback_force.move_toward(Vector2.ZERO, knockback_decay * delta)
		velocity = knockback_force
		move_and_slide()
		return

	# Don't act while stunned from taking damage
	if is_stunned:
		return

	# Movement + attack
	if player_chase and player != null:
		if position.distance_to(player.position) > 15:
			play_animation("walking")
			var direction = (player.position - position).normalized()
			velocity = direction * speed
			$AnimatedSprite2D.flip_h = player.position.x < position.x
		elif player_inattack_zone and can_attack and not is_attacking:
			velocity = Vector2.ZERO
			_start_attack()
		else:
			velocity = Vector2.ZERO
	else:
		play_animation("idle")
		velocity = Vector2.ZERO

	move_and_slide()

# --- Start attack ---
func _start_attack():
	is_attacking = true
	can_attack = false
	play_animation("attack")
	$attack_damage_timer.start()
	$attack_cooldown.start()

# --- Area Enter/Exit ---
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

func _on_enemy_hitbox_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inattack_zone = false

# --- Deal damage to player ---
func _on_attack_damage_timer_timeout():
	if is_dead or not is_attacking or not player_inattack_zone or player == null:
		return

	if player.has_method("is_player_attacking") and player.is_player_attacking():
		print("Enemy attack cancelled — player is attacking!")
		is_attacking = false
		return

	if player.has_method("take_damage"):
		player.call("take_damage", 10)
		fx_axe_hit.play()
		print("Enemy dealt damage to player!")

	if player.has_method("apply_knockback"):
		player.apply_knockback(global_position)

	is_attacking = false

# --- Take damage ---
func take_damage(amount: int):
	if not can_take_damage or is_dead:
		return

	health -= amount
	can_take_damage = false
	is_attacking = false
	is_stunned = true
	$attack_damage_timer.stop()
	$scream_timer.start()

	if not player_chase:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			player = players[0]
			player_chase = true
			print("Enemy aggroed from damage!")

	play_animation("damaged")
	print("Enemy took damage! Health:", health)
	$take_damage_cooldown.start()

	if health <= 0:
		die()
		fx_death.play()

# --- Death ---
func die():
	is_dead = true
	is_stunned = false
	play_animation("death")
	$death_timer.start()

# --- Timers ---
func _on_take_damage_cooldown_timeout() -> void:
	can_take_damage = true
	is_stunned = false

func _on_attack_cooldown_timeout() -> void:
	can_attack = true

func _on_death_timer_timeout() -> void:
	queue_free()

# --- Animation Helper ---
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

func _on_scream_timer_timeout() -> void:
	if is_dead:
		return
	fx_goblin_scream.play(0.61)
