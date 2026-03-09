extends StaticBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

# --- Settings ---
const MAX_HITS = 3              # ← breaks after 3 hits
var hit_count: int = 0
var is_destroyed: bool = false
var is_playing_anim: bool = false   # ← prevents spam hits during animation

func _ready():
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("idle")

# ─────────────────────────────────────────────
# TAKE DAMAGE — called by player or enemy
# ─────────────────────────────────────────────
func take_damage(amount: int = 1):
	if is_destroyed or is_playing_anim:
		return

	hit_count += 1
	print("Hit count:", hit_count, "/", MAX_HITS)

	if hit_count >= MAX_HITS:
		_play_break()
	else:
		_play_damaged()

# ─────────────────────────────────────────────
# ANIMATIONS
# ─────────────────────────────────────────────
func _play_damaged():
	is_playing_anim = true
	sprite.play("damaged")

func _play_break():
	is_destroyed = true
	is_playing_anim = true
	# Disable collision immediately
	collision.set_deferred("disabled", true)
	sprite.play("break")

func _on_animation_finished():
	var anim = sprite.animation

	if anim == "damaged":
		is_playing_anim = false
		sprite.play("idle")      # ← return to idle after flinch

	elif anim == "break":
		queue_free()             # ← remove from scene after break anim
