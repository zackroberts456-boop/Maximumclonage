extends Node2D

const Player = preload("res://scripts/actors/player.gd")
const TestEnemy = preload("res://scripts/actors/test_enemy.gd")
const Checkpoint = preload("res://scripts/world/checkpoint.gd")
const WeaponPickup = preload("res://scripts/world/weapon_pickup.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const DebugOverlay = preload("res://scripts/ui/debug_overlay.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")

const STAGE_ID = "stage_01_killing_floor"
const STAGE_LENGTH = 2400.0
const TILE_SIZE = 16

var player
var message_label
var handling_death = false
var stage_complete = false
var tile_texture
var background_texture
var wave_counts = {1: 0, 2: 0, 3: 0}
var gates = {}

func _ready():
    tile_texture = load("res://assets/environment/lab_tiles_16.png")
    background_texture = load("res://assets/environment/lab_panel_240x160.png")
    GameState.begin_stage(STAGE_ID, Vector2(48, 118))
    _build_background()
    _build_geometry()
    _spawn_gameplay()
    _build_ui()
    _show_stage_intro()

func _process(_delta):
    if stage_complete or player == null:
        return
    if player.global_position.x >= STAGE_LENGTH - 52.0 and int(wave_counts[3]) <= 0:
        _complete_stage_slice()

func _build_background():
    var panel_count = int(ceil(STAGE_LENGTH / 240.0))
    for i in range(panel_count):
        var sprite = Sprite2D.new()
        sprite.texture = background_texture
        sprite.centered = false
        sprite.position = Vector2(i * 240, 0)
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        sprite.z_index = -30
        var brightness = 0.70 + float(i % 3) * 0.055
        sprite.modulate = Color(brightness, brightness + 0.04, brightness, 1.0)
        add_child(sprite)

        if i > 0:
            var seam = Line2D.new()
            seam.points = PackedVector2Array([Vector2(i * 240, 18), Vector2(i * 240, 136)])
            seam.width = 2.0
            seam.default_color = Color(0.20, 0.55, 0.28, 0.22)
            seam.z_index = -20
            add_child(seam)

    var shadow = Polygon2D.new()
    shadow.polygon = PackedVector2Array([
        Vector2(0, 0), Vector2(STAGE_LENGTH, 0),
        Vector2(STAGE_LENGTH, 160), Vector2(0, 160)
    ])
    shadow.color = Color(0.0, 0.03, 0.02, 0.10)
    shadow.z_index = -28
    add_child(shadow)

    for x in [228.0, 468.0, 708.0, 948.0, 1188.0, 1428.0, 1668.0, 1908.0, 2148.0, 2388.0]:
        var glow = Polygon2D.new()
        glow.polygon = PackedVector2Array([
            Vector2(x, 24), Vector2(x + 4, 24), Vector2(x + 4, 134), Vector2(x, 134)
        ])
        glow.color = Color(0.25, 1.0, 0.18, 0.09)
        glow.z_index = -24
        add_child(glow)

    _add_world_label(Vector2(18, 42), "SECTOR A // ENTRY LINE", Color(0.55, 1.0, 0.32, 0.48))
    _add_world_label(Vector2(492, 42), "SECTOR B // CROSSFIRE BAY", Color(0.55, 1.0, 0.32, 0.44))
    _add_world_label(Vector2(982, 42), "SECTOR C // TRANSFER SHAFT", Color(0.55, 1.0, 0.32, 0.44))
    _add_world_label(Vector2(1450, 42), "SECTOR D // PURGE LINE", Color(1.0, 0.72, 0.22, 0.46))
    _add_world_label(Vector2(1940, 42), "SECTOR E // KILL FLOOR", Color(1.0, 0.55, 0.20, 0.50))

func _build_geometry():
    # ROOM 1: movement/shooting runway with one safe elevated target line.
    _add_solid_rect(Rect2(0, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(144, 108, 72, 16), 1, false)

    # ROOM 2: one clean commitment jump with optional upper recovery route.
    _add_solid_rect(Rect2(240, 136, 80, 24), 0, false)
    _add_solid_rect(Rect2(352, 136, 128, 24), 0, false)
    _add_solid_rect(Rect2(270, 106, 72, 16), 1, false)
    _add_solid_rect(Rect2(372, 98, 76, 16), 1, false)
    _add_instant_hazard(Rect2(320, 150, 32, 12))

    # ROOM 3: LOCKDOWN CROSSFIRE. The exit gate opens only when both guards die.
    _add_solid_rect(Rect2(480, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(516, 110, 76, 16), 1, false)
    _add_solid_rect(Rect2(620, 90, 84, 16), 1, false)
    _add_cover_post(604, 112, 24)
    gates[1] = _create_lock_gate(714.0)

    # ROOM 4: checkpoint / recovery room with a forgiving jump after the arena.
    _add_solid_rect(Rect2(720, 136, 124, 24), 0, false)
    _add_solid_rect(Rect2(876, 136, 84, 24), 0, false)
    _add_solid_rect(Rect2(790, 108, 64, 16), 1, false)
    _add_solid_rect(Rect2(880, 100, 64, 16), 1, false)
    _add_instant_hazard(Rect2(844, 150, 32, 12))

    # ROOM 5: vertical-priority chamber. A lift creates timing instead of static stairs.
    _add_solid_rect(Rect2(960, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(1088, 84, 88, 16), 1, false)
    _add_moving_platform(Vector2(1016, 118), Vector2(1016, 82), Vector2(52, 10), 1.75)
    _add_cover_post(1180, 104, 32)

    # ROOM 6: toxic transfer line. Two short lethal gaps with a moving bridge choice.
    _add_solid_rect(Rect2(1200, 136, 64, 24), 0, false)
    _add_solid_rect(Rect2(1296, 136, 80, 24), 0, false)
    _add_solid_rect(Rect2(1408, 136, 32, 24), 0, false)
    _add_solid_rect(Rect2(1218, 104, 62, 16), 1, false)
    _add_solid_rect(Rect2(1360, 88, 64, 16), 1, false)
    _add_moving_platform(Vector2(1304, 103), Vector2(1342, 103), Vector2(48, 10), 1.60)
    _add_instant_hazard(Rect2(1264, 150, 32, 12))
    _add_instant_hazard(Rect2(1376, 150, 32, 12))

    # ROOM 7: second checkpoint and pressure LOCKDOWN arena.
    _add_solid_rect(Rect2(1440, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(1504, 104, 64, 16), 1, false)
    _add_solid_rect(Rect2(1600, 104, 64, 16), 1, false)
    _add_cover_post(1584, 112, 24)
    gates[2] = _create_lock_gate(1674.0)

    # ROOM 8: crossfire over a wide toxic trench. Moving platform is the safe route;
    # skilled players may clear the whole gap from the upper ledge.
    _add_solid_rect(Rect2(1680, 136, 116, 24), 0, false)
    _add_solid_rect(Rect2(1840, 136, 80, 24), 0, false)
    _add_solid_rect(Rect2(1710, 104, 72, 16), 1, false)
    _add_solid_rect(Rect2(1844, 94, 64, 16), 1, false)
    _add_moving_platform(Vector2(1800, 118), Vector2(1830, 118), Vector2(42, 10), 1.35)
    _add_instant_hazard(Rect2(1796, 150, 44, 12))

    # ROOM 9: final gauntlet. No pit pressure; threat comes from three mobile enemies.
    _add_solid_rect(Rect2(1920, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(1952, 102, 72, 16), 1, false)
    _add_solid_rect(Rect2(2072, 102, 72, 16), 1, false)
    _add_cover_post(2040, 112, 24)

    # ROOM 10: elite kill-floor clearance. Exit stays sealed until the elite dies.
    _add_solid_rect(Rect2(2160, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(2196, 104, 76, 16), 1, false)
    _add_solid_rect(Rect2(2280, 88, 64, 16), 1, false)
    gates[3] = _create_lock_gate(2340.0)
    _build_exit_gate(Vector2(2350, 64))

func _add_cover_post(x: float, y: float, height: float):
    _add_solid_rect(Rect2(x, y, 16, height), 1, false)

func _add_solid_rect(rect: Rect2, tile_variant: int, hazard_edge: bool):
    var body = StaticBody2D.new()
    body.collision_layer = 1
    body.collision_mask = 0
    body.position = rect.position + rect.size * 0.5

    var collider = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = rect.size
    collider.shape = shape
    body.add_child(collider)
    add_child(body)

    var columns = int(ceil(rect.size.x / float(TILE_SIZE)))
    var rows = int(ceil(rect.size.y / float(TILE_SIZE)))
    for row in range(rows):
        for column in range(columns):
            var tile = Sprite2D.new()
            var atlas = AtlasTexture.new()
            atlas.atlas = tile_texture
            atlas.region = Rect2(tile_variant * 16, 0, 16, 16)
            tile.texture = atlas
            tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            tile.position = rect.position + Vector2(column * 16 + 8, row * 16 + 8)
            tile.z_index = -2
            add_child(tile)

    var edge = Line2D.new()
    edge.points = PackedVector2Array([
        Vector2(rect.position.x, rect.position.y + 1),
        Vector2(rect.position.x + rect.size.x, rect.position.y + 1)
    ])
    edge.width = 1.0
    edge.default_color = Color(1.0, 0.55, 0.12, 0.62) if hazard_edge else Color(0.35, 1.0, 0.20, 0.40)
    edge.z_index = -1
    add_child(edge)

func _add_moving_platform(start_position: Vector2, end_position: Vector2, platform_size: Vector2, travel_time: float):
    var body = AnimatableBody2D.new()
    body.collision_layer = 1
    body.collision_mask = 0
    body.position = start_position
    body.sync_to_physics = true

    var collider = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = platform_size
    collider.shape = shape
    body.add_child(collider)

    var panel = Polygon2D.new()
    panel.polygon = PackedVector2Array([
        Vector2(-platform_size.x * 0.5, -platform_size.y * 0.5),
        Vector2(platform_size.x * 0.5, -platform_size.y * 0.5),
        Vector2(platform_size.x * 0.5, platform_size.y * 0.5),
        Vector2(-platform_size.x * 0.5, platform_size.y * 0.5)
    ])
    panel.color = Color(0.08, 0.14, 0.11, 0.98)
    panel.z_index = -1
    body.add_child(panel)

    var rail = Line2D.new()
    rail.points = PackedVector2Array([
        Vector2(-platform_size.x * 0.5 + 2.0, -platform_size.y * 0.5 + 1.0),
        Vector2(platform_size.x * 0.5 - 2.0, -platform_size.y * 0.5 + 1.0)
    ])
    rail.width = 1.0
    rail.default_color = Color(0.40, 1.0, 0.25, 0.72)
    body.add_child(rail)
    add_child(body)

    var tween = create_tween().set_loops()
    tween.tween_property(body, "position", end_position, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(body, "position", start_position, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _add_instant_hazard(rect: Rect2):
    var area = Area2D.new()
    area.collision_layer = 0
    area.collision_mask = 2
    area.monitoring = true
    var shape_node = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = rect.size
    shape_node.shape = shape
    shape_node.position = rect.position + rect.size * 0.5
    area.add_child(shape_node)
    area.body_entered.connect(_on_instant_hazard_body_entered)
    add_child(area)

    var toxic = Polygon2D.new()
    toxic.polygon = PackedVector2Array([
        rect.position,
        Vector2(rect.end.x, rect.position.y),
        rect.end,
        Vector2(rect.position.x, rect.end.y)
    ])
    toxic.color = Color(0.25, 1.0, 0.08, 0.35)
    toxic.z_index = -3
    add_child(toxic)

func _on_instant_hazard_body_entered(body):
    if body.is_in_group("players") and body.has_method("take_damage"):
        body.health.force_kill()

func _create_lock_gate(x: float):
    var gate = StaticBody2D.new()
    gate.collision_layer = 1
    gate.collision_mask = 0
    gate.position = Vector2(x, 84)

    var collider = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(8, 104)
    collider.shape = shape
    gate.add_child(collider)

    var beam = Line2D.new()
    beam.points = PackedVector2Array([Vector2(0, -50), Vector2(0, 50)])
    beam.width = 4.0
    beam.default_color = Color(0.55, 1.0, 0.18, 0.76)
    gate.add_child(beam)

    var beam_inner = Line2D.new()
    beam_inner.points = PackedVector2Array([Vector2(0, -50), Vector2(0, 50)])
    beam_inner.width = 1.0
    beam_inner.default_color = Color(0.92, 1.0, 0.82, 0.90)
    gate.add_child(beam_inner)

    add_child(gate)
    return gate

func _open_gate(wave_id: int):
    if not gates.has(wave_id):
        return
    var gate = gates[wave_id]
    if gate == null or not is_instance_valid(gate):
        return
    gate.collision_layer = 0
    var tween = create_tween()
    tween.tween_property(gate, "modulate", Color(1, 1, 1, 0), 0.24)
    tween.finished.connect(gate.queue_free)
    gates[wave_id] = null
    _flash_message("LOCKDOWN %d CLEARED" % wave_id, 1.0)

func _build_exit_gate(pos: Vector2):
    var frame = Polygon2D.new()
    frame.polygon = PackedVector2Array([
        pos, pos + Vector2(42, 0), pos + Vector2(42, 72), pos + Vector2(0, 72)
    ])
    frame.color = Color(0.02, 0.05, 0.04, 0.88)
    frame.z_index = -5
    add_child(frame)

    var left = Line2D.new()
    left.points = PackedVector2Array([pos + Vector2(4, 6), pos + Vector2(4, 68)])
    left.width = 3.0
    left.default_color = Color(0.35, 1.0, 0.18, 0.62)
    left.z_index = -4
    add_child(left)

    var right = Line2D.new()
    right.points = PackedVector2Array([pos + Vector2(38, 6), pos + Vector2(38, 68)])
    right.width = 3.0
    right.default_color = Color(0.35, 1.0, 0.18, 0.62)
    right.z_index = -4
    add_child(right)

    _add_world_label(pos + Vector2(5, 24), "EXIT", Color(0.68, 1.0, 0.38, 0.82))

func _spawn_gameplay():
    player = Player.new()
    player.setup(GameState.selected_character)
    player.global_position = GameState.stage_start_position
    add_child(player)
    player.died.connect(_on_player_died)
    player.camera.limit_right = int(STAGE_LENGTH)
    player.camera.limit_bottom = 160

    # Free-roaming enemies establish the stage language before locked encounters.
    _spawn_enemy(Vector2(190, 118), -1)
    _spawn_enemy(Vector2(286, 118), 1)
    _spawn_enemy(Vector2(420, 118), -1)

    # Lockdown 1: two staggered-height mobile guards.
    _spawn_enemy(Vector2(548, 90), -1, 1)
    _spawn_enemy(Vector2(670, 70), 1, 1)

    _spawn_enemy(Vector2(812, 90), 1)
    _spawn_enemy(Vector2(916, 82), -1)
    _spawn_enemy(Vector2(1018, 118), 1)
    _spawn_enemy(Vector2(1130, 66), -1)
    _spawn_enemy(Vector2(1238, 88), 1)
    _spawn_enemy(Vector2(1348, 78), -1)

    # Lockdown 2: flat arena pair designed around strafing/retreat behavior.
    _spawn_enemy(Vector2(1538, 118), 1, 2)
    _spawn_enemy(Vector2(1642, 118), -1, 2)

    _spawn_enemy(Vector2(1738, 86), 1)
    _spawn_enemy(Vector2(1870, 74), -1)

    # Final gauntlet and elite. Nothing here can be skipped by sprinting to the exit.
    _spawn_enemy(Vector2(1980, 82), 1, 3)
    _spawn_enemy(Vector2(2100, 82), -1, 3)
    _spawn_enemy(Vector2(2260, 118), -1, 3, true)

    var pickup = WeaponPickup.new()
    pickup.global_position = Vector2(660, 68)
    add_child(pickup)

    _spawn_checkpoint(Vector2(754, 118), Vector2(770, 118))
    _spawn_checkpoint(Vector2(1466, 118), Vector2(1488, 118))

func _spawn_enemy(pos: Vector2, initial_direction: int = -1, wave_id: int = 0, elite: bool = false):
    var enemy = TestEnemy.new()
    enemy.patrol_direction = initial_direction
    if elite:
        enemy.make_elite()
    enemy.global_position = pos
    enemy.defeated.connect(_on_enemy_defeated.bind(wave_id))
    add_child(enemy)
    if wave_id > 0:
        wave_counts[wave_id] = int(wave_counts[wave_id]) + 1
    return enemy

func _on_enemy_defeated(_enemy, wave_id: int):
    if wave_id <= 0:
        return
    wave_counts[wave_id] = max(0, int(wave_counts[wave_id]) - 1)
    if int(wave_counts[wave_id]) == 0:
        _open_gate(wave_id)

func _spawn_checkpoint(marker_position: Vector2, respawn_position: Vector2):
    var checkpoint = Checkpoint.new()
    checkpoint.setup(respawn_position)
    checkpoint.global_position = marker_position
    add_child(checkpoint)

func _build_ui():
    var hud = Hud.new()
    hud.setup(player)
    add_child(hud)

    if not OS.has_feature("mobile"):
        var debug = DebugOverlay.new()
        debug.setup(player)
        add_child(debug)

    var touch_layer = CanvasLayer.new()
    touch_layer.layer = 40
    add_child(touch_layer)
    var touch = TouchControls.new()
    touch_layer.add_child(touch)

    var message_layer = CanvasLayer.new()
    message_layer.layer = 45
    add_child(message_layer)
    message_label = Label.new()
    message_label.position = Vector2(24, 34)
    message_label.size = Vector2(192, 18)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.add_theme_font_size_override("font_size", 7)
    message_label.add_theme_color_override("font_color", Color(0.82, 1.0, 0.55))
    message_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    message_label.add_theme_constant_override("shadow_offset_x", 1)
    message_label.add_theme_constant_override("shadow_offset_y", 1)
    message_layer.add_child(message_label)

func _show_stage_intro():
    message_label.text = "STAGE 1 // KILLING FLOOR INFILTRATION"
    await get_tree().create_timer(1.8).timeout
    if message_label != null and not stage_complete:
        message_label.text = ""

func _flash_message(text_value: String, duration: float):
    if message_label == null:
        return
    message_label.text = text_value
    await get_tree().create_timer(duration).timeout
    if message_label != null and message_label.text == text_value and not stage_complete:
        message_label.text = ""

func _on_player_died(_dead_player):
    if handling_death:
        return
    handling_death = true
    var has_lives = GameState.lose_life()
    if has_lives:
        message_label.text = "CHECKPOINT RESTART"
        await get_tree().create_timer(0.65).timeout
        player.respawn_at(GameState.checkpoint_position)
        message_label.text = ""
        handling_death = false
    else:
        message_label.text = "CONTINUE // RESTARTING STAGE"
        await get_tree().create_timer(1.0).timeout
        GameState.continue_stage()
        get_tree().reload_current_scene()

func _complete_stage_slice():
    if stage_complete:
        return
    stage_complete = true
    player.heal(GameState.max_hp)
    SaveManager.submit_high_score(STAGE_ID, GameState.score)
    message_label.text = "KILLING FLOOR SECTOR CLEARED"
    await get_tree().create_timer(1.8).timeout
    get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

func _add_world_label(pos: Vector2, text_value: String, color: Color):
    var label = Label.new()
    label.position = pos
    label.text = text_value
    label.add_theme_font_size_override("font_size", 6)
    label.add_theme_color_override("font_color", color)
    label.z_index = -12
    add_child(label)
