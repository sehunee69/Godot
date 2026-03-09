extends Area2D

func _ready():
	monitoring = true    # ← make sure monitoring is on
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("OnBridgeArea ready!")

func _on_body_entered(body):
	print("Body entered OnBridgeArea:", body.name)  # ← test if this prints
	if body.is_in_group("player"):
		body.z_index = 3
		print("Player z_index set to 3")

func _on_body_exited(body):
	print("Body exited OnBridgeArea:", body.name)
	if body.is_in_group("player"):
		body.z_index = 0
		print("Player z_index back to 0")
