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
    if stage_complete:
        return
    if player != null and player.global_position.x >= STAGE_LENGTH - 74.0:
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
        var brightness = 0.72 + float(i % 3) * 0.055
        sprite.modulate = Color(brightness, brightness + 0.04, brightness, 1.0)
        add_child(sprite)

        # Room seams make the stage read as authored spaces rather than one endless strip.
        if i > 0:
            var seam = Line2D.new()
            seam.points = PackedVector2Array([Vector2(i * 240, 18), Vector2(i * 240, 136)])
            seam.width = 2.0
            seam.default_color = Color(0.20, 0.55, 0.28, 0.24)
            seam.z_index = -20
            add_child(seam)

    var shadow = Polygon2D.new()
    shadow.polygon = PackedVector2Array([
        Vector2(0, 0), Vector2(STAGE_LENGTH, 0),
        Vector2(STAGE_LENGTH, 160), Vector2(0, 160)
    ])
    shadow.color = Color(0.0, 0.03, 0.02, 0.12)
    shadow.z_index = -28
    add_child(shadow)

    for x in [228.0, 468.0, 708.0, 948.0, 1188.0, 1428.0, 1668.0, 1908.0, 2148.0, 2388.0]:
        var glow = Polygon2D.new()
        glow.polygon = PackedVector2Array([
            Vector2(x, 26), Vector2(x + 4, 26), Vector2(x + 4, 132), Vector2(x, 132)
        ])
        glow.color = Color(0.25, 1.0, 0.18, 0.10)
        glow.z_index = -24
        add_child(glow)

    _add_world_label(Vector2(18, 42), "SECTOR A // ENTRY LINE", Color(0.55, 1.0, 0.32, 0.48))
    _add_world_label(Vector2(492, 42), "SECTOR B // CROSSFIRE BAY", Color(0.55, 1.0, 0.32, 0.44))
    _add_world_label(Vector2(982, 42), "SECTOR C // TRANSFER SHAFT", Color(0.55, 1.0, 0.32, 0.44))
    _add_world_label(Vector2(1450, 42), "SECTOR D // PURGE LINE", Color(1.0, 0.72, 0.22, 0.46))
    _add_world_label(Vector2(1940, 42), "SECTOR E // KILL FLOOR", Color(1.0, 0.55, 0.20, 0.50))

func _build_geometry():
    # Room 1 (0-240): safe runway. Teach movement + firing before demanding a jump.
    _add_solid_rect(Rect2(0, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(144, 112, 72, 16), 1, false)

    # Room 2 (240-480): first readable 32px pit with an optional high route.
    _add_solid_rect(Rect2(240, 136, 80, 24), 0, false)
    _add_solid_rect(Rect2(352, 136, 128, 24), 0, false)
    _add_solid_rect(Rect2(272, 108, 72, 16), 1, false)
    _add_solid_rect(Rect2(368, 104, 80, 16), 1, false)

    # Room 3 (480-720): crossfire bay. Continuous floor, staggered firing heights.
    _add_solid_rect(Rect2(480, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(520, 112, 72, 16), 1, false)
    _add_solid_rect(Rect2(616, 96, 88, 16), 1, false)
    _add_cover_post(604, 112, 24)

    # Room 4 (720-960): checkpoint then a second pit with a forgiving bridge route.
    _add_solid_rect(Rect2(720, 136, 124, 24), 0, false)
    _add_solid_rect(Rect2(876, 136, 84, 24), 0, false)
    _add_solid_rect(Rect2(792, 112, 64, 16), 1, false)
    _add_solid_rect(Rect2(880, 104, 64, 16), 1, false)

    # Room 5 (960-1200): staircase chamber. Introduces vertical target priority.
    _add_solid_rect(Rect2(960, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(992, 112, 80, 16), 1, false)
    _add_solid_rect(Rect2(1088, 88, 88, 16), 1, false)
    _add_cover_post(1180, 104, 32)

    # Room 6 (1200-1440): two short toxic-transfer gaps with overhead recovery route.
    _add_solid_rect(Rect2(1200, 136, 64, 24), 0, false)
    _add_solid_rect(Rect2(1296, 136, 80, 24), 0, false)
    _add_solid_rect(Rect2(1408, 136, 32, 24), 0, false)
    _add_solid_rect(Rect2(1224, 108, 72, 16), 1, false)
    _add_solid_rect(Rect2(1320, 100, 72, 16), 1, false)
    _add_solid_rect(Rect2(1392, 84, 48, 16), 1, false)

    # Room 7 (1440-1680): second checkpoint, then a flat pressure arena.
    _add_solid_rect(Rect2(1440, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(1512, 108, 64, 16), 1, false)
    _add_solid_rect(Rect2(1600, 108, 64, 16), 1, false)
    _add_cover_post(1584, 112, 24)

    # Room 8 (1680-1920): moving crossfire + one 36px commitment jump.
    _add_solid_rect(Rect2(1680, 136, 120, 24), 0, false)
    _add_solid_rect(Rect2(1836, 136, 84, 24), 0, false)
    _add_solid_rect(Rect2(1712, 108, 72, 16), 1, false)
    _add_solid_rect(Rect2(1816, 96, 80, 16), 1, false)

    # Room 9 (1920-2160): pre-exit gauntlet. No pits; difficulty is enemy composition.
    _add_solid_rect(Rect2(1920, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(1952, 104, 72, 16), 1, false)
    _add_solid_rect(Rect2(2072, 104, 72, 16), 1, false)
    _add_cover_post(2040, 112, 24)

    # Room 10 (2160-2400): decompression / exit approach. Give the player breathing room.
    _add_solid_rect(Rect2(2160, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(2200, 108, 80, 16), 1, false)
    _build_exit_gate(Vector2(2338, 64))

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
    edge.default_color = Color(1.0, 0.55, 0.12, 0.62) if hazard_edge else Color(0.35, 1.0, 0.20, 0.42)
    edge.z_index = -1
    add_child(edge)

func _build_exit_gate(pos: Vector2):
    var frame = Polygon2D.new()
    frame.polygon = PackedVector2Array([
        pos, pos + Vector2(44, 0), pos + Vector2(44, 72), pos + Vector2(0, 72)
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
    right.points = PackedVector2Array([pos + Vector2(40, 6), pos + Vector2(40, 68)])
    right.width = 3.0
    right.default_color = Color(0.35, 1.0, 0.18, 0.62)
    right.z_index = -4
    add_child(right)

    _add_world_label(pos + Vector2(6, 24), "EXIT", Color(0.68, 1.0, 0.38, 0.82))

func _spawn_gameplay():
    player = Player.new()
    player.setup(GameState.selected_character)
    player.global_position = GameState.stage_start_position
    add_child(player)
    player.died.connect(_on_player_died)
    player.camera.limit_right = int(STAGE_LENGTH)
    player.camera.limit_bottom = 160

    # Encounters are authored by room: teach -> test -> escalate -> recover.
    _spawn_enemy(Vector2(190, 118), -1)

    _spawn_enemy(Vector2(286, 118), 1)
    _spawn_enemy(Vector2(420, 118), -1)

    _spawn_enemy(Vector2(548, 92), -1)
    _spawn_enemy(Vector2(668, 76), 1)

    _spawn_enemy(Vector2(812, 92), 1)
    _spawn_enemy(Vector2(916, 84), -1)

    _spawn_enemy(Vector2(1016, 118), 1)
    _spawn_enemy(Vector2(1132, 68), -1)

    _spawn_enemy(Vector2(1238, 90), 1)
    _spawn_enemy(Vector2(1348, 80), -1)

    _spawn_enemy(Vector2(1538, 118), 1)
    _spawn_enemy(Vector2(1642, 118), -1)

    _spawn_enemy(Vector2(1740, 88), 1)
    _spawn_enemy(Vector2(1870, 76), -1)

    _spawn_enemy(Vector2(1980, 84), 1)
    _spawn_enemy(Vector2(2100, 84), -1)
    _spawn_enemy(Vector2(2238, 88), -1)

    var pickup = WeaponPickup.new()
    pickup.global_position = Vector2(660, 72)
    add_child(pickup)

    _spawn_checkpoint(Vector2(754, 118), Vector2(770, 118))
    _spawn_checkpoint(Vector2(1466, 118), Vector2(1488, 118))

func _spawn_enemy(pos: Vector2, initial_direction: int = -1):
    var enemy = TestEnemy.new()
    enemy.patrol_direction = initial_direction
    enemy.global_position = pos
    add_child(enemy)

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
    await get_tree().create_timer(2.0).timeout
    if message_label != null and not stage_complete:
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
