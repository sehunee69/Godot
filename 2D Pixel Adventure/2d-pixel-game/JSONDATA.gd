extends Node

var item_data = {}

func _ready():
	item_data = LoadData("res://Data/ItemData.json")

func LoadData(file_path):
	var file = FileAccess.open(file_path, FileAccess.READ)  # File.new() is now FileAccess
	if file == null:
		print("Failed to open file: ", file_path)
		return {}
	var json_string = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json_string)  # JSON,parse is now JSON.parse_string
	if parsed == null:
		print("Failed to parse JSON")
		return {}
	return parsed
