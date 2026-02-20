extends Node2D

@onready var fx_axe_hit: AudioStreamPlayer2D = $fx_axeHit
@onready var fx_death: AudioStreamPlayer2D = $fx_death

var speed = 50
var player_chase = false
var player = null

var health = 100
var player_inattack_zone = false
var can_take_damage = true
var can_attack = true
var is_dead = false

var knockback_force = Vector2.ZERO
var knockback_strength = 200.0
var knockback_decay = 800.0

var current_animation = ""

func _ready():
	play_animation("idle")

func _physics_process(delta):
	if is_dead:
		return

	# Knockback logic
	if knockback_force.length() > 0.1:
		position += knockback_force * delta
		knockback_force = knockback_force.move_toward(Vector2.ZERO, knockback_decay * delta)
		return

	# Movement + attack
	if player_chase:
		if position.distance_to(player.position) > 15:
			position += (player.position - position).normalized() * speed * delta
			play_animation("walking")

			$AnimatedSprite2D.flip_h = player.position.x < position.x
		elif player_inattack_zone and can_attack:
			play_animation("attack")
			can_attack = false
			$attack_cooldown.start()
			$attack_damage_timer.start()
	else:
		play_animation("idle")


# --- Area Enter/Exit ---
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player = body
		player_chase = true

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player_chase = false
		player = null

func _on_enemy_hitbox_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player_inattack_zone = true

func _on_enemy_hitbox_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		player_inattack_zone = false


# --- DAMAGE TO PLAYER ---
func _on_attack_damage_timer_timeout():
	if is_dead or !player_inattack_zone or player == null:
		return

	if player.has_method("take_damage"):
		player.call("take_damage", 10)
		fx_axe_hit.play()
		print("Enemy dealt damage to player!")

func take_damage(amount: int):
	if !can_take_damage or is_dead:
		return
	health -= amount
	can_take_damage = false
	play_animation("damaged")
	print("Enemy took damage! Health:", health)
	$take_damage_cooldown.start()

	if health <= 0:
		die()
		fx_death.play()



# --- Death ---
func die():
	is_dead = true
	play_animation("death")
	$death_timer.start()

# --- Timers ---
func _on_take_damage_cooldown_timeout() -> void:
	can_take_damage = true

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
