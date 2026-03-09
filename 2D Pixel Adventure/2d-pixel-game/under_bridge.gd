extends Area2D

# Z index values
const Z_NORMAL = 0       # walking on ground normally
const Z_UNDER_BRIDGE = -1  # walking under bridge (drawn below it)

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	# Player goes under bridge
	if body.is_in_group("player"):
		body.z_index = Z_UNDER_BRIDGE
		print("Player went under bridge")
	# Enemies go under bridge
	if body.is_in_group("enemies"):
		body.z_index = Z_UNDER_BRIDGE

func _on_body_exited(body):
	# Restore normal Z when leaving
	if body.is_in_group("player"):
		body.z_index = Z_NORMAL
		print("Player left bridge area")
	if body.is_in_group("enemies"):
		body.z_index = Z_NORMAL
