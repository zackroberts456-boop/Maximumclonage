extends Node2D

const Player = preload("res://scripts/actors/player.gd")
const TestEnemy = preload("res://scripts/actors/test_enemy.gd")
const KillingFloorRotor = preload("res://scripts/actors/killing_floor_rotor.gd")
const Checkpoint = preload("res://scripts/world/checkpoint.gd")
const WeaponPickup = preload("res://scripts/world/weapon_pickup.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const DebugOverlay = preload("res://scripts/ui/debug_overlay.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")

const STAGE_ID = "stage_01_killing_floor"
const STAGE_LENGTH = 2880.0
const TILE_SIZE = 16
const FLOOR_Y = 136.0
const BOSS_ARENA_START = 2640.0
const BOSS_TRIGGER_X = 2670.0

var player
var boss
var message_label
var handling_death = false
var stage_complete = false
var tile_texture
var background_texture
var wave_counts = {1: 0, 2: 0, 3: 0}
var gates = {}
var boss_active = false
var boss_defeated = false
var boss_left_gate
var boss_right_gate
var boss_hud_root
var boss_bar_fill
var boss_bar_label

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

    if not boss_active and not boss_defeated and player.global_position.x >= BOSS_TRIGGER_X:
        _activate_boss_encounter()

    if boss_defeated and player.global_position.x >= STAGE_LENGTH - 48.0:
        _complete_stage_slice()

func _build_background():
    var panel_count = int(ceil(STAGE_LENGTH / 240.0))
    for i in range(panel_count):
        var panel = Sprite2D.new()
        panel.texture = background_texture
        panel.centered = false
        panel.position = Vector2(i * 240, 0)
        panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        panel.z_index = -30
        var brightness = 0.69 + float(i % 3) * 0.05
        panel.modulate = Color(brightness, brightness + 0.045, brightness, 1.0)
        add_child(panel)

        if i > 0:
            var seam = Line2D.new()
            seam.points = PackedVector2Array([Vector2(i * 240, 18), Vector2(i * 240, 136)])
            seam.width = 2.0
            seam.default_color = Color(0.20, 0.55, 0.28, 0.18)
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

    # Room dividers and low-intensity light columns help visual geometry line up with gameplay rooms.
    for x in range(228, int(STAGE_LENGTH), 240):
        var glow = Polygon2D.new()
        glow.polygon = PackedVector2Array([
            Vector2(float(x), 24), Vector2(float(x + 4), 24),
            Vector2(float(x + 4), 134), Vector2(float(x), 134)
        ])
        glow.color = Color(0.25, 1.0, 0.18, 0.08)
        glow.z_index = -24
        add_child(glow)

    _add_world_label(Vector2(18, 42), "SECTOR A // ENTRY", Color(0.55, 1.0, 0.32, 0.48))
    _add_world_label(Vector2(500, 42), "SECTOR B // CROSSFIRE", Color(0.55, 1.0, 0.32, 0.44))
    _add_world_label(Vector2(982, 42), "SECTOR C // LIFT SHAFT", Color(0.55, 1.0, 0.32, 0.44))
    _add_world_label(Vector2(1460, 42), "SECTOR D // PURGE LINE", Color(1.0, 0.72, 0.22, 0.46))
    _add_world_label(Vector2(1944, 42), "SECTOR E // KILL FLOOR", Color(1.0, 0.55, 0.20, 0.50))
    _add_world_label(Vector2(2420, 42), "SECTOR F // ROTOR CORE", Color(1.0, 0.38, 0.18, 0.56))

func _build_geometry():
    # Platforming metrics are authored around the canonical movement envelope:
    # ~58 px full-jump rise and ~80 px practical horizontal reach on Normal.
    # Mandatory gaps stay mostly 32-48 px; 56+ px routes are optional or assisted.

    # ROOM 1 (0-240): safe movement runway + one elevated route.
    _add_solid_rect(Rect2(0, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(128, 108, 64, 16), 1, false)

    # ROOM 2 (240-480): first real jump. A 48px toxic gap has a narrow recovery brace.
    _add_solid_rect(Rect2(240, 136, 72, 24), 0, true)
    _add_solid_rect(Rect2(360, 136, 120, 24), 0, true)
    _add_solid_rect(Rect2(320, 124, 32, 12), 1, true)
    _add_solid_rect(Rect2(270, 102, 56, 16), 1, false)
    _add_solid_rect(Rect2(384, 94, 72, 16), 1, false)
    _add_instant_hazard(Rect2(312, 148, 48, 18))

    # ROOM 3 (480-720): LOCKDOWN CROSSFIRE. Combat first, platforming second.
    _add_solid_rect(Rect2(480, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(524, 112, 64, 16), 1, false)
    _add_solid_rect(Rect2(624, 96, 64, 16), 1, false)
    _add_cover_post(600, 112, 24)
    gates[1] = _create_lock_gate(712.0)

    # ROOM 4 (720-960): checkpoint + three-step maintenance climb. No death pit here.
    _add_solid_rect(Rect2(720, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(760, 120, 48, 16), 1, false)
    _add_solid_rect(Rect2(824, 104, 48, 16), 1, false)
    _add_solid_rect(Rect2(888, 88, 56, 16), 1, false)

    # ROOM 5 (960-1200): lift-shaft timing challenge. Gap is survivable only by landing the lift.
    _add_solid_rect(Rect2(960, 136, 64, 24), 0, true)
    _add_solid_rect(Rect2(1080, 136, 120, 24), 0, true)
    _add_solid_rect(Rect2(984, 104, 48, 16), 1, false)
    _add_solid_rect(Rect2(1096, 104, 48, 16), 1, false)
    _add_solid_rect(Rect2(1152, 88, 40, 16), 1, false)
    _add_moving_platform(Vector2(1042, 120), Vector2(1064, 88), Vector2(38, 10), 1.45)
    _add_instant_hazard(Rect2(1024, 148, 56, 18))

    # ROOM 6 (1200-1440): toxic sluice. Low route = short island jumps; high route = clean skill line.
    _add_solid_rect(Rect2(1200, 136, 64, 24), 0, true)
    _add_solid_rect(Rect2(1304, 136, 40, 24), 0, true)
    _add_solid_rect(Rect2(1392, 136, 48, 24), 0, true)
    _add_solid_rect(Rect2(1224, 104, 48, 16), 1, false)
    _add_solid_rect(Rect2(1288, 88, 48, 16), 1, false)
    _add_solid_rect(Rect2(1352, 104, 48, 16), 1, false)
    _add_moving_platform(Vector2(1362, 122), Vector2(1384, 106), Vector2(34, 10), 1.30)
    _add_instant_hazard(Rect2(1264, 148, 40, 18))
    _add_instant_hazard(Rect2(1344, 148, 48, 18))

    # ROOM 7 (1440-1680): checkpoint + pressure LOCKDOWN arena.
    _add_solid_rect(Rect2(1440, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(1504, 104, 64, 16), 1, false)
    _add_solid_rect(Rect2(1600, 104, 64, 16), 1, false)
    _add_cover_post(1584, 112, 24)
    gates[2] = _create_lock_gate(1672.0)

    # ROOM 8 (1680-1920): multi-jump trench with distinct low and high routes.
    _add_solid_rect(Rect2(1680, 136, 56, 24), 0, true)
    _add_solid_rect(Rect2(1888, 136, 32, 24), 0, true)
    _add_solid_rect(Rect2(1704, 96, 52, 16), 1, false)
    _add_solid_rect(Rect2(1776, 80, 48, 16), 1, false)
    _add_solid_rect(Rect2(1848, 96, 52, 16), 1, false)
    _add_moving_platform(Vector2(1754, 124), Vector2(1796, 124), Vector2(38, 10), 1.35)
    _add_solid_rect(Rect2(1816, 116, 36, 12), 1, false)
    _add_moving_platform(Vector2(1860, 124), Vector2(1880, 108), Vector2(34, 10), 1.20)
    _add_instant_hazard(Rect2(1736, 148, 152, 18))

    # ROOM 9 (1920-2160): descending maintenance stacks over a long trench.
    _add_solid_rect(Rect2(1920, 136, 48, 24), 0, true)
    _add_solid_rect(Rect2(2128, 136, 32, 24), 0, true)
    _add_solid_rect(Rect2(1984, 88, 48, 16), 1, false)
    _add_solid_rect(Rect2(2048, 104, 48, 16), 1, false)
    _add_solid_rect(Rect2(2112, 120, 32, 16), 1, false)
    _add_instant_hazard(Rect2(1968, 148, 160, 18))

    # ROOM 10 (2160-2400): final standard-enemy LOCKDOWN. Route choices remain open during combat.
    _add_solid_rect(Rect2(2160, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(2192, 112, 56, 16), 1, false)
    _add_solid_rect(Rect2(2272, 88, 56, 16), 1, false)
    _add_solid_rect(Rect2(2344, 112, 40, 16), 1, false)
    _add_cover_post(2256, 112, 24)
    gates[3] = _create_lock_gate(2392.0)

    # ROOM 11 (2400-2640): pre-boss traversal + boss checkpoint. Two short gaps, one high route.
    _add_solid_rect(Rect2(2400, 136, 72, 24), 0, true)
    _add_solid_rect(Rect2(2512, 136, 48, 24), 0, true)
    _add_solid_rect(Rect2(2600, 136, 40, 24), 0, true)
    _add_solid_rect(Rect2(2432, 104, 48, 16), 1, false)
    _add_solid_rect(Rect2(2496, 88, 48, 16), 1, false)
    _add_solid_rect(Rect2(2552, 104, 48, 16), 1, false)
    _add_solid_rect(Rect2(2600, 88, 40, 16), 1, false)
    _add_instant_hazard(Rect2(2472, 148, 40, 18))
    _add_instant_hazard(Rect2(2560, 148, 40, 18))

    # ROOM 12 (2640-2880): dedicated boss arena. No pits: difficulty comes from patterns.
    _add_solid_rect(Rect2(2640, 136, 240, 24), 0, false)
    _add_solid_rect(Rect2(2664, 96, 48, 16), 1, false)
    _add_solid_rect(Rect2(2808, 96, 48, 16), 1, false)
    boss_right_gate = _create_lock_gate(2870.0)
    _build_exit_gate(Vector2(2832, 64))

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
    edge.default_color = Color(1.0, 0.55, 0.12, 0.68) if hazard_edge else Color(0.35, 1.0, 0.20, 0.42)
    edge.z_index = -1
    add_child(edge)

    # Elevated platforms get visible structural supports so art placement reads as architecture,
    # not floating collision rectangles disconnected from the background.
    if rect.position.y < 132.0 and rect.size.x >= 32.0:
        _add_platform_supports(rect)

func _add_platform_supports(rect: Rect2):
    var underside = Line2D.new()
    underside.points = PackedVector2Array([
        Vector2(rect.position.x + 2.0, rect.end.y),
        Vector2(rect.end.x - 2.0, rect.end.y)
    ])
    underside.width = 2.0
    underside.default_color = Color(0.08, 0.16, 0.13, 0.72)
    underside.z_index = -6
    add_child(underside)

    var support_count = max(1, int(floor(rect.size.x / 32.0)))
    for i in range(support_count):
        var t = (float(i) + 0.5) / float(support_count)
        var support_x = lerp(rect.position.x + 6.0, rect.end.x - 6.0, t)
        var support = Line2D.new()
        support.points = PackedVector2Array([
            Vector2(support_x, rect.end.y),
            Vector2(support_x, FLOOR_Y)
        ])
        support.width = 2.0
        support.default_color = Color(0.07, 0.14, 0.12, 0.52)
        support.z_index = -7
        add_child(support)

func _add_moving_platform(start_position: Vector2, end_position: Vector2, platform_size: Vector2, travel_time: float):
    var guide = Line2D.new()
    guide.points = PackedVector2Array([start_position, end_position])
    guide.width = 1.0
    guide.default_color = Color(0.30, 0.72, 0.36, 0.22)
    guide.z_index = -8
    add_child(guide)

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
    panel.color = Color(0.07, 0.13, 0.10, 0.98)
    panel.z_index = -1
    body.add_child(panel)

    var rail = Line2D.new()
    rail.points = PackedVector2Array([
        Vector2(-platform_size.x * 0.5 + 2.0, -platform_size.y * 0.5 + 1.0),
        Vector2(platform_size.x * 0.5 - 2.0, -platform_size.y * 0.5 + 1.0)
    ])
    rail.width = 1.0
    rail.default_color = Color(0.46, 1.0, 0.28, 0.78)
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
    toxic.color = Color(0.25, 1.0, 0.08, 0.42)
    toxic.z_index = -3
    add_child(toxic)

    var warning = Line2D.new()
    warning.points = PackedVector2Array([
        Vector2(rect.position.x, rect.position.y),
        Vector2(rect.end.x, rect.position.y)
    ])
    warning.width = 2.0
    warning.default_color = Color(0.68, 1.0, 0.20, 0.72)
    warning.z_index = -2
    add_child(warning)

func _on_instant_hazard_body_entered(body):
    if body.is_in_group("players"):
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
    _open_gate_node(gates[wave_id])
    gates[wave_id] = null
    _flash_message("LOCKDOWN %d CLEARED" % wave_id, 1.0)

func _open_gate_node(gate):
    if gate == null or not is_instance_valid(gate):
        return
    gate.collision_layer = 0
    var tween = create_tween()
    tween.tween_property(gate, "modulate", Color(1, 1, 1, 0), 0.24)
    tween.finished.connect(gate.queue_free)

func _build_exit_gate(pos: Vector2):
    var frame = Polygon2D.new()
    frame.polygon = PackedVector2Array([
        pos, pos + Vector2(42, 0), pos + Vector2(42, 72), pos + Vector2(0, 72)
    ])
    frame.color = Color(0.02, 0.05, 0.04, 0.88)
    frame.z_index = -5
    add_child(frame)

    for x_offset in [4.0, 38.0]:
        var side = Line2D.new()
        side.points = PackedVector2Array([pos + Vector2(x_offset, 6), pos + Vector2(x_offset, 68)])
        side.width = 3.0
        side.default_color = Color(0.35, 1.0, 0.18, 0.62)
        side.z_index = -4
        add_child(side)

    _add_world_label(pos + Vector2(5, 24), "EXIT", Color(0.68, 1.0, 0.38, 0.82))

func _spawn_gameplay():
    player = Player.new()
    player.setup(GameState.selected_character)
    player.global_position = GameState.stage_start_position
    add_child(player)
    player.died.connect(_on_player_died)
    player.camera.limit_right = int(STAGE_LENGTH)
    player.camera.limit_bottom = 160

    # Enemy positions use surface-top coordinates so feet, collision, and platforms line up.
    _spawn_enemy_on_surface(188, 136, -1)
    _spawn_enemy_on_surface(420, 136, -1)

    # Lockdown 1.
    _spawn_enemy_on_surface(548, 136, -1, 1)
    _spawn_enemy_on_surface(654, 96, 1, 1)

    # Stair / lift / sluice pressure stays sparse so platform timing remains readable.
    _spawn_enemy_on_surface(836, 104, 1)
    _spawn_enemy_on_surface(1120, 104, -1)
    _spawn_enemy_on_surface(1238, 104, 1)
    _spawn_enemy_on_surface(1408, 136, -1)

    # Lockdown 2.
    _spawn_enemy_on_surface(1528, 136, 1, 2)
    _spawn_enemy_on_surface(1632, 104, -1, 2)

    # Trench / descending stacks use high targets, not enemies sitting on landing zones.
    _spawn_enemy_on_surface(1872, 96, -1)
    _spawn_enemy_on_surface(2068, 104, 1)

    # Lockdown 3: three-point crossfire before the boss approach.
    _spawn_enemy_on_surface(2208, 136, 1, 3)
    _spawn_enemy_on_surface(2300, 88, -1, 3)
    _spawn_enemy_on_surface(2364, 112, -1, 3, true)

    _spawn_enemy_on_surface(2528, 136, 1)

    var pickup = WeaponPickup.new()
    pickup.global_position = Vector2(656, 72)
    add_child(pickup)

    _spawn_checkpoint(Vector2(740, 118), Vector2(752, 118))
    _spawn_checkpoint(Vector2(1452, 118), Vector2(1468, 118))
    _spawn_checkpoint(Vector2(2418, 118), Vector2(2432, 118))

    _spawn_boss()

func _spawn_enemy_on_surface(x: float, surface_y: float, initial_direction: int = -1, wave_id: int = 0, elite: bool = false):
    var enemy = TestEnemy.new()
    enemy.patrol_direction = initial_direction
    if elite:
        enemy.make_elite()
    enemy.global_position = Vector2(x, surface_y - 12.0)
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

func _spawn_boss():
    boss = KillingFloorRotor.new()
    boss.setup(2680.0, 2848.0)
    boss.global_position = Vector2(2784, 136)
    boss.defeated.connect(_on_boss_defeated)
    boss.health_changed.connect(_on_boss_health_changed)
    add_child(boss)
    boss.set_active(false)
    _on_boss_health_changed(48, 48)

func _activate_boss_encounter():
    if boss_active or boss_defeated or boss == null:
        return
    boss_active = true
    boss_left_gate = _create_lock_gate(BOSS_ARENA_START + 8.0)
    boss.set_active(true)
    if boss_hud_root != null:
        boss_hud_root.visible = true
    _on_boss_health_changed(boss.health.current_hp, boss.health.max_hp)
    _flash_message("KILLING FLOOR ROTOR // ENGAGED", 1.0)

func _on_boss_health_changed(current_hp, max_hp):
    if boss_bar_fill == null:
        return
    var ratio = clamp(float(current_hp) / float(max(1, max_hp)), 0.0, 1.0)
    boss_bar_fill.size = Vector2(120.0 * ratio, 4.0)
    if boss_bar_label != null:
        boss_bar_label.text = "KILLING FLOOR ROTOR  %02d/%02d" % [current_hp, max_hp]

func _on_boss_defeated(_defeated_boss):
    boss_defeated = true
    boss_active = false
    _open_gate_node(boss_left_gate)
    _open_gate_node(boss_right_gate)
    boss_left_gate = null
    boss_right_gate = null
    if boss_hud_root != null:
        boss_hud_root.visible = false
    _flash_message("ROTOR DESTROYED // EXIT OPEN", 1.35)

func _reset_boss_encounter():
    if boss_defeated:
        return
    boss_active = false
    if boss != null and is_instance_valid(boss):
        boss.queue_free()
    if boss_left_gate != null and is_instance_valid(boss_left_gate):
        boss_left_gate.queue_free()
    boss_left_gate = null
    if boss_hud_root != null:
        boss_hud_root.visible = false
    _spawn_boss()

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

    _build_boss_hud()

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

func _build_boss_hud():
    var layer = CanvasLayer.new()
    layer.layer = 44
    add_child(layer)

    boss_hud_root = Control.new()
    boss_hud_root.position = Vector2(52, 5)
    boss_hud_root.size = Vector2(136, 18)
    boss_hud_root.visible = false
    layer.add_child(boss_hud_root)

    var panel = ColorRect.new()
    panel.position = Vector2.ZERO
    panel.size = Vector2(136, 18)
    panel.color = Color(0.01, 0.03, 0.025, 0.82)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    boss_hud_root.add_child(panel)

    boss_bar_label = Label.new()
    boss_bar_label.position = Vector2(4, 1)
    boss_bar_label.size = Vector2(128, 7)
    boss_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boss_bar_label.add_theme_font_size_override("font_size", 5)
    boss_bar_label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.68))
    boss_hud_root.add_child(boss_bar_label)

    var bar_bg = ColorRect.new()
    bar_bg.position = Vector2(8, 11)
    bar_bg.size = Vector2(120, 4)
    bar_bg.color = Color(0.12, 0.15, 0.13, 0.95)
    bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    boss_hud_root.add_child(bar_bg)

    boss_bar_fill = ColorRect.new()
    boss_bar_fill.position = Vector2(8, 11)
    boss_bar_fill.size = Vector2(120, 4)
    boss_bar_fill.color = Color(0.42, 1.0, 0.20, 0.90)
    boss_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    boss_hud_root.add_child(boss_bar_fill)

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
    var died_during_boss = boss_active and not boss_defeated
    var has_lives = GameState.lose_life()
    if has_lives:
        message_label.text = "CHECKPOINT RESTART"
        await get_tree().create_timer(0.65).timeout
        if died_during_boss:
            _reset_boss_encounter()
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
