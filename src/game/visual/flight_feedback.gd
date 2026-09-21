extends Node
class_name FlightFeedback

const BURST_SCENE := preload("res://src/game/visual/world_burst.tscn")

@export var world_path: NodePath
@export var post_process_path: NodePath

var _world: Node2D
var _post_process: WorldPostProcess
var _pending_palette: Dictionary = {}
var _players: Dictionary = {}

func configure(palette: Dictionary) -> void:
	_pending_palette = palette.duplicate(true)
	if is_node_ready():
		_apply_palette()

func _ready() -> void:
	_world = get_node(world_path) as Node2D
	_post_process = get_node(post_process_path) as WorldPostProcess
	assert(_world != null, "FlightFeedback requires world root.")
	assert(_post_process != null, "FlightFeedback requires WorldPostProcess.")

	_players = {
		"scanner": _create_player(ProceduralSfx.scanner_ping(), -10.0),
		"collect": _create_player(ProceduralSfx.collect(), -7.0),
		"discovery": _create_player(ProceduralSfx.discovery(), -4.0),
		"unload": _create_player(ProceduralSfx.unload(), -6.0),
		"perfect": _create_player(ProceduralSfx.perfect(), -3.0),
		"impact": _create_player(ProceduralSfx.impact(), -9.0),
	}
	_apply_palette()

func target_acquired(definition: SalvageDefinition) -> void:
	if definition == null:
		return
	var player := _players.get("scanner") as AudioStreamPlayer
	if player == null:
		return
	match String(definition.rarity):
		"epic":
			player.pitch_scale = 1.18
		"rare":
			player.pitch_scale = 1.08
		_:
			player.pitch_scale = 1.0
	player.play()

func salvage_collected(definition: SalvageDefinition, is_new_discovery: bool, position: Vector2) -> void:
	if definition == null:
		return
	var rarity_color := WorldVisualLanguage.salvage_rarity_color(definition.rarity)
	var rarity_name := String(definition.rarity)
	var intensity := 1.0
	if rarity_name == "rare":
		intensity = 1.35
	elif rarity_name == "epic":
		intensity = 1.75

	_spawn_burst(position, rarity_color, intensity)
	if is_new_discovery:
		_play("discovery")
		_post_process.pulse(rarity_color, 0.20 if rarity_name == "rare" else 0.27, 0.48)
	else:
		_play("collect")
		if rarity_name in ["rare", "epic"]:
			_post_process.pulse(rarity_color, 0.10, 0.26)

func cargo_unloaded(units: int, position: Vector2) -> void:
	var intensity := clampf(0.8 + float(units) * 0.05, 0.8, 1.55)
	_spawn_burst(position, WorldVisualLanguage.salvage_progress_color(), intensity)
	_play("unload")
	_post_process.pulse(WorldVisualLanguage.salvage_progress_color(), 0.075, 0.24)

func contract_target_reached() -> void:
	_post_process.pulse(WorldVisualLanguage.salvage_recovery_color(), 0.09, 0.28)

func perfect_cleanup() -> void:
	_play("perfect")
	_post_process.pulse(Color("#ffe59a"), 0.22, 0.62)

func ship_bumped(intensity: float, position: Vector2) -> void:
	var player := _players.get("impact") as AudioStreamPlayer
	if player != null:
		player.pitch_scale = lerpf(1.12, 0.82, clampf(intensity, 0.0, 1.0))
		player.volume_db = lerpf(-12.0, -6.0, clampf(intensity, 0.0, 1.0))
		player.play()
	if intensity >= 0.38:
		_spawn_burst(position, WorldVisualLanguage.hazard_color(), 0.55 + intensity * 0.55)

func _spawn_burst(position: Vector2, color: Color, intensity: float) -> void:
	if _world == null:
		return
	var burst := BURST_SCENE.instantiate() as WorldBurst
	assert(burst != null, "WorldBurst scene must instantiate.")
	_world.add_child(burst)
	burst.global_position = position
	burst.play(color, intensity)

func _play(key: String) -> void:
	var player := _players.get(key) as AudioStreamPlayer
	if player != null:
		player.pitch_scale = 1.0
		player.play()

func _create_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player

func _apply_palette() -> void:
	if _post_process == null or _pending_palette.is_empty():
		return
	_post_process.configure(_pending_palette)
