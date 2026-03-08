extends Control

const SlotClass = preload("res://slot.gd")
@onready var inventory_slots = $TextureRect/ScrollContainer/MarginContainer/GridContainer
var holding_item = null

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for inv_slot in inventory_slots.get_children():
		inv_slot.mouse_filter = Control.MOUSE_FILTER_STOP
		inv_slot.gui_input.connect(func(event): _on_slot_clicked(event, inv_slot))
	
	var slots = inventory_slots.get_children()
	
	var item1 = preload("res://item.tscn").instantiate()
	slots[0].putIntoSlot(item1)
	item1.set_item("Sakura Blade")
	
	var item2 = preload("res://item.tscn").instantiate()
	slots[1].putIntoSlot(item2)
	item2.set_item("Conquerers Fury")

func _on_slot_clicked(event: InputEvent, slot):
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	get_viewport().set_input_as_handled()

	if holding_item != null:
		if not slot.has_item:
			slot.putIntoSlot(holding_item)
			holding_item = null
		else:
			var temp_item = slot.item
			slot.pickFromSlot()
			slot.putIntoSlot(holding_item)
			holding_item = temp_item
	else:
		if slot.has_item:
			holding_item = slot.item
			slot.pickFromSlot()
#func slot_gui_input(event: InputEvent, slot):
	#if event is InputEventMouseButton:
		#if event.button_index == MOUSE_BUTTON_LEFT && event.pressed:  
			#if holding_item != null:
				#if !slot.item:
					#slot.putIntoSlot(holding_item)
					#holding_item = null
				#else:
					#var temp_item = slot.item
					#slot.pickFromSlot()  
					#temp_item.global_position = event.global_position
					#slot.putIntoSlot(holding_item)
					#holding_item = temp_item
			#elif slot.item:
				#holding_item = slot.item
				#slot.pickFromSlot()
				#holding_item.global_position = get_global_mouse_position()

func _process(_delta):
	if holding_item:
		holding_item.global_position = get_global_mouse_position()
