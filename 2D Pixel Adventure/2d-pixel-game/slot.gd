extends Panel

var equipped_tex = preload("res://Assets/equipped.png")
var empty_tex = preload("res://Assets/emptySlot.png")


var equipped_style: StyleBoxTexture = null
var empty_style: StyleBoxTexture = null

var itemClass = preload("res://item.tscn")
var item = null

func _ready():
	equipped_style = StyleBoxTexture.new()
	empty_style = StyleBoxTexture.new()
	equipped_style.texture = equipped_tex
	empty_style.texture = empty_tex
	
	if randi() % 2 == 0:
		item = itemClass.instantiate()
		add_child(item)	
	refresh_style()
	
func refresh_style():
	if item == null:
		set('custom_styles/panel', empty_style)
	else:
		set('custom_styles/panel', equipped_style)
