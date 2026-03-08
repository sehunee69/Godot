extends CanvasLayer

@onready var bar_fill = $boss_health_bar/BarFill
@onready var boss_bar = $boss_health_bar
@onready var boss_name_label = $boss_health_bar/Label

const BAR_FULL_WIDTH = 269.0   # ← width of your bar in pixels
func _ready():
	print("bar_fill:", bar_fill)
	print("boss_bar:", boss_bar)
	print("boss_name_label:", boss_name_label)
	print("BarFill node size:", bar_fill.size)

func show_boss_bar(boss_name: String):
	boss_name_label.text = boss_name
	boss_bar.visible = true

func hide_boss_bar():
	boss_bar.visible = false

func update_boss_health(current: int, maximum: int):
	bar_fill.max_value = maximum
	bar_fill.value = current
