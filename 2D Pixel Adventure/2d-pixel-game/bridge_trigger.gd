extends Area2D

@export var player_z: int = 2
@export var is_on_top: bool = false
@export var trigger_priority: int = 0 # Used only for handoff after lock owner exits
@export var default_player_z: int = 2
@export_range(1, 32) var bridge_block_bit: int = 7

# All trigger instances
static var _all_triggers: Array = []
# player_id -> trigger that currently owns control (first-enter lock)
static var _locked_trigger_by_player: Dictionary = {}

# per trigger: player_id -> overlapping shape count
var _shape_counts: Dictionary = {}

func _ready() -> void:
	monitoring = true
	monitorable = true
	body_shape_entered.connect(_on_body_shape_entered)
	body_shape_exited.connect(_on_body_shape_exited)
	if !_all_triggers.has(self):
		_all_triggers.append(self)

func _exit_tree() -> void:
	_all_triggers.erase(self)

func _on_body_shape_entered(_rid: RID, body: Node, _body_shape: int, _local_shape: int) -> void:
	if !body.is_in_group("player") or !(body is CollisionObject2D):
		return

	var id := body.get_instance_id()
	_shape_counts[id] = int(_shape_counts.get(id, 0)) + 1
	if _shape_counts[id] > 1:
		return

	# First-enter lock: if someone already owns this player, ignore overwrite.
	if _locked_trigger_by_player.has(id):
		return

	_locked_trigger_by_player[id] = self
	_apply_to_player(body as CollisionObject2D)
	print("LOCKED:", name, " on_top:", is_on_top)

func _on_body_shape_exited(_rid: RID, body: Node, _body_shape: int, _local_shape: int) -> void:
	if !body.is_in_group("player") or !(body is CollisionObject2D):
		return

	var id := body.get_instance_id()
	var next_count := int(_shape_counts.get(id, 0)) - 1
	if next_count > 0:
		_shape_counts[id] = next_count
		return

	_shape_counts.erase(id)

	# Only unlock/handoff if this trigger owns the lock.
	if _locked_trigger_by_player.get(id, null) != self:
		return

	_locked_trigger_by_player.erase(id)

	# Handoff: choose any other trigger still overlapping this player.
	var next_trigger: Area2D = _find_handoff_trigger(id)
	if next_trigger != null:
		_locked_trigger_by_player[id] = next_trigger
		next_trigger._apply_to_player(body as CollisionObject2D)
		print("HANDOFF:", next_trigger.name, " on_top:", next_trigger.is_on_top)
	else:
		_restore_player(body as CollisionObject2D)
		print("UNLOCKED: default restored")

func _find_handoff_trigger(player_id: int) -> Area2D:
	var best: Area2D = null
	for t in _all_triggers:
		if int(t._shape_counts.get(player_id, 0)) <= 0:
			continue
		if best == null or t.trigger_priority > best.trigger_priority:
			best = t
	return best

func _apply_to_player(body: CollisionObject2D) -> void:
	if body is Node2D:
		(body as Node2D).z_index = player_z
	body.set_collision_mask_value(bridge_block_bit, is_on_top)

func _restore_player(body: CollisionObject2D) -> void:
	if body is Node2D:
		(body as Node2D).z_index = default_player_z
	body.set_collision_mask_value(bridge_block_bit, false)
