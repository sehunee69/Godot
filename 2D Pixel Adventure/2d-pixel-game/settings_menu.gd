extends CanvasLayer

@onready var volume_slider : HSlider = $ColorRect/VBoxContainer/HBoxContainer/VolumeSlider
@onready var btn_back      : Button  = $ColorRect/VBoxContainer/Back

func _ready():
	volume_slider.value = AudioServer.get_bus_volume_db(0)  # load current volume
	volume_slider.value_changed.connect(_on_volume_changed)
	btn_back.pressed.connect(_on_back)

func _on_volume_changed(value: float):
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

func _on_back():
	queue_free()
