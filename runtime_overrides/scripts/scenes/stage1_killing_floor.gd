extends Node2D

const Player = preload("res://scripts/actors/player.gd")
const TestEnemy = preload("res://scripts/actors/test_enemy.gd")
const Checkpoint = preload("res://scripts/world/checkpoint.gd")
const WeaponPickup = preload("res://scripts/world/weapon_pickup.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const DebugOverlay = preload("res://scripts/ui/debug_overlay.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")

const STAGE_ID = "stage_01_killing_floor"
const STAGE_LENGTH = 2320.0
const FLOOR_Y = 136.0
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
    if player != null and player.global_position.x >= STAGE_LENGTH - 72.0:
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
        var brightness = 0.72 + float(i % 3) * 0.06
        sprite.modulate = Color(brightness, brightness + 0.04, brightness, 1.0)
        add_child(sprite)

    var shadow = Polygon2D.new()
    shadow.polygon = PackedVector2Array([
        Vector2(0, 0), Vector2(STAGE_LENGTH, 0),
        Vector2(STAGE_LENGTH, 160), Vector2(0, 160)
    ])
    shadow.color = Color(0.0, 0.03, 0.02, 0.14)
    shadow.z_index = -28
    add_child(shadow)

    for x in [320.0, 704.0, 1088.0, 1472.0, 1856.0, 2208.0]:
        var glow = Polygon2D.new()
        glow.polygon = PackedVector2Array([
            Vector2(x, 26), Vector2(x + 5, 26), Vector2(x + 5, 132), Vector2(x, 132)
        ])
        glow.color = Color(0.25, 1.0, 0.18, 0.11)
        glow.z_index = -24
        add_child(glow)

    _add_world_label(Vector2(18, 42), "FACILITY-12 // KILLING FLOOR", Color(0.55, 1.0, 0.32, 0.42))
    _add_world_label(Vector2(815, 42), "SECTOR B // CLONE TRANSFER", Color(0.55, 1.0, 0.32, 0.38))
    _add_world_label(Vector2(1610, 42), "SECTOR C // PURGE LINE", Color(1.0, 0.72, 0.22, 0.42))

func _build_geometry():
    # Main route: short readable gaps, escalating platform rhythm, no blind leaps.
    _add_solid_rect(Rect2(0, 136, 400, 24), 0, true)
    _add_solid_rect(Rect2(448, 136, 384, 24), 0, true)
    _add_solid_rect(Rect2(832, 136, 320, 24), 0, true)
    _add_solid_rect(Rect2(1200, 136, 432, 24), 0, true)
    _add_solid_rect(Rect2(1680, 136, 640, 24), 0, true)

    # Alternate/high-ground route. All characters can make every jump.
    _add_solid_rect(Rect2(176, 104, 128, 16), 1, false)
    _add_solid_rect(Rect2(512, 104, 112, 16), 1, false)
    _add_solid_rect(Rect2(640, 88, 96, 16), 1, false)
    _add_solid_rect(Rect2(896, 104, 128, 16), 1, false)
    _add_solid_rect(Rect2(1056, 88, 96, 16), 1, false)
    _add_solid_rect(Rect2(1264, 104, 112, 16), 1, false)
    _add_solid_rect(Rect2(1392, 88, 112, 16), 1, false)
    _add_solid_rect(Rect2(1512, 72, 96, 16), 1, false)
    _add_solid_rect(Rect2(1760, 104, 112, 16), 1, false)
    _add_solid_rect(Rect2(1888, 88, 112, 16), 1, false)
    _add_solid_rect(Rect2(2032, 104, 112, 16), 1, false)
    _add_solid_rect(Rect2(2160, 88, 96, 16), 1, false)

    # Cover/door-frame obstacles that force short hops and firing-angle changes.
    _add_solid_rect(Rect2(352, 112, 16, 24), 1, false)
    _add_solid_rect(Rect2(784, 112, 16, 24), 1, false)
    _add_solid_rect(Rect2(1136, 104, 16, 32), 1, false)
    _add_solid_rect(Rect2(1616, 104, 16, 32), 1, false)
    _add_solid_rect(Rect2(2016, 112, 16, 24), 1, false)

    _build_exit_gate(Vector2(2264, 64))

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
        Vector2(rect.end.x, rect.position.y + 1)
    ])
    edge.width = 1.0
    edge.default_color = Color(1.0, 0.55, 0.12, 0.62) if hazard_edge else Color(0.35, 1.0, 0.20, 0.48)
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

    var enemy_positions = [
        Vector2(250, 118), Vector2(374, 118),
        Vector2(548, 86), Vector2(704, 70),
        Vector2(912, 118), Vector2(1016, 118),
        Vector2(1296, 86), Vector2(1460, 70),
        Vector2(1712, 118), Vector2(1840, 86),
        Vector2(2056, 86), Vector2(2192, 70)
    ]
    for pos in enemy_positions:
        _spawn_enemy(pos)

    var pickup = WeaponPickup.new()
    pickup.global_position = Vector2(688, 66)
    add_child(pickup)

    _spawn_checkpoint(Vector2(848, 118), Vector2(864, 118))
    _spawn_checkpoint(Vector2(1648, 118), Vector2(1696, 118))

func _spawn_enemy(pos: Vector2):
    var enemy = TestEnemy.new()
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
