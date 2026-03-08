extends CharacterBody2D

const SPEED = 225
var item_name
var player = null
var being_picked_up = false
var collected = false  

func _ready():
	item_name = "Sakura Blade"
	add_to_group("items")
	print("item drop created: ", self)
	
func _physics_process(delta):
	if being_picked_up and not collected:
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * SPEED
		move_and_slide()
		
		if global_position.distance_to(player.global_position) < 15:
			collected = true  
			add_to_inventory()
				
#func _physics_process(delta):
	#if being_picked_up:
		#var direction = global_position.direction_to(player.global_position)
		#velocity = direction * SPEED
		#move_and_slide()
		#
		#if global_position.distance_to(player.global_position) < 15:
			#add_to_inventory()

func pick_up_item(body):
	player = body
	being_picked_up = true

func add_to_inventory():
	print("add_to_inventory called by: ", self)
	var inventory = get_tree().get_first_node_in_group("inventory")
	if inventory == null:
		print("No inventory found!")
		queue_free()
		return
	
	var slots = inventory.inventory_slots.get_children()
	for slot in slots:
		if not slot.has_item:
			var new_item = preload("res://item.tscn").instantiate()
			slot.putIntoSlot(new_item)
			new_item.call_deferred("set_item", item_name)  # wait until node is ready
			queue_free()
			return
	
	print("Inventory is full!")
	queue_free()
