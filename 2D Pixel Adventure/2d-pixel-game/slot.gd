extends Panel

var legendary_Slot = preload("res://Assets/slots/legend_Slot.png")
var epic_Slot = preload("res://Assets/slots/epic_Slot.png")
var rare_Slot = preload("res://Assets/slots/rare_Slot.png")
var common_Slot = preload("res://Assets/slots/common_Slot.png")
var uncommon_Slot = preload("res://Assets/slots/uncommon_Slot.png")
@onready var hover_sprite = $hover_sprite

var legendary_style: StyleBoxTexture = null
var epic_style: StyleBoxTexture = null
var rare_style: StyleBoxTexture = null
var common_style: StyleBoxTexture = null
var uncommon_style: StyleBoxTexture = null

var ItemClass = preload("res://item.tscn")
var item = null
var has_item: bool = false

func _ready():
	legendary_style = StyleBoxTexture.new()
	epic_style = StyleBoxTexture.new()
	rare_style = StyleBoxTexture.new()
	common_style = StyleBoxTexture.new()
	uncommon_style = StyleBoxTexture.new()
	
	legendary_style.texture = legendary_Slot
	epic_style.texture = epic_Slot
	rare_style.texture = rare_Slot
	common_style.texture = common_Slot
	uncommon_style.texture = uncommon_Slot
	
	has_item = false
	
	#if randi() % 2 == 0:
		#item = ItemClass.instantiate()
		#add_child(item)
		#item.set_random_texture()
		#has_item = true  
		
	hover_sprite.visible = false
	hover_sprite.position = size / 2
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	refresh_style()
	

func _on_mouse_entered():
	if not has_item:
		return
	hover_sprite.visible = true
	hover_sprite.play()


func _on_mouse_exited():
	hover_sprite.visible = false
	hover_sprite.stop()
	
	
func refresh_style():
	if not has_item:
		add_theme_stylebox_override("panel", uncommon_style)
	else:
		add_theme_stylebox_override("panel", legendary_style)

func pickFromSlot():
	if not has_item:
		return
		
	remove_child(item)
	var inventoryNode = find_parent("Control")
	inventoryNode.add_child(item)
	item.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	item.size = Vector2(24, 24)  # match your slot size
	has_item = false
	item = null
	refresh_style()		
#func pickFromSlot():
	#if not has_item:
		#return
	#remove_child(item)
	#var inventoryNode = find_parent("Control")
	#inventoryNode.add_child(item)
	#has_item = false
	#item = null
	#refresh_style()
func putIntoSlot(new_item):
	if has_item:
		#print("slot already has item, returning")
		return
	#print("putting item into slot: ", new_item)
	item = new_item
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	add_child(item)
	item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	has_item = true
	refresh_style()
	#print("slot now has item: ", has_item)
	
#func putIntoSlot(new_item):
	#if has_item:
		#return
	#item = new_item
	#if item.get_parent() != null:
		#item.get_parent().remove_child(item)
	#add_child(item)
	#item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	#has_item = true
	#refresh_style()

func initialize_item(item_name, item_quantity):
	if item == null:
		item = ItemClass.instantiate()
		add_child(item)
		item.set_item(item_name, item_quantity)
	else:
		item.set_item(item_name, item_quantity)
	refresh_style()
