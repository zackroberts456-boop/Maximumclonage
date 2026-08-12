extends "res://scripts/scenes/stage1_killing_floor_v06.gd"

const PlayerV07 = preload("res://scripts/actors/player_v06.gd")
const AcidSpitter = preload("res://scripts/actors/acid_spitter.gd")
const WeaponPickupV07 = preload("res://scripts/world/weapon_pickup.gd")

const STABLE_BACKGROUND = "res://assets/environment/lab_panel_240x160.png"
const PROD_TILES = "res://assets/environment/lab_tiles_prod_16.png"

var theme_tints = [
    Color(0.82, 0.96, 0.86, 1.0),
    Color(0.72, 0.88, 1.00, 1.0),
    Color(0.92, 0.76, 1.00, 1.0),
    Color(1.00, 0.76, 0.62, 1.0),
    Color(0.72, 1.00, 0.76, 1.0),
    Color(1.00, 0.62, 0.48, 1.0)
]

func _build_background():
    # v0.7 stable keeps the proven 240x160 archive panel as a corruption-proof base,
    # then builds six visually distinct sectors from procedural pixel-safe dressing.
    # This avoids repeating the exact same room while keeping every gameplay surface
    # readable on a phone-sized screen.
    var panel_texture = load(STABLE_BACKGROUND)
    for panel_index in range(12):
        var theme_index = min(5, int(panel_index / 2))
        var panel = Sprite2D.new()
        panel.texture = panel_texture
        panel.centered = false
        panel.position = Vector2(panel_index * 240, 0)
        panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        panel.modulate = theme_tints[theme_index]
        panel.z_index = -40
        add_child(panel)

        _add_sector_dressing(panel_index, theme_index)

        if panel_index > 0:
            var seam = Line2D.new()
            seam.points = PackedVector2Array([
                Vector2(panel_index * 240, 18),
                Vector2(panel_index * 240, 134)
            ])
            seam.width = 1.0
            seam.default_color = Color(0.35, 0.92, 0.42, 0.12)
            seam.z_index = -28
            add_child(seam)

    var depth_tint = Polygon2D.new()
    depth_tint.polygon = PackedVector2Array([
        Vector2(0, 0), Vector2(STAGE_LENGTH, 0),
        Vector2(STAGE_LENGTH, 160), Vector2(0, 160)
    ])
    depth_tint.color = Color(0.0, 0.025, 0.018, 0.08)
    depth_tint.z_index = -27
    add_child(depth_tint)

    _add_world_label(Vector2(18, 42), "SECTOR A // ENTRY LINE", Color(0.55, 1.0, 0.32, 0.46))
    _add_world_label(Vector2(492, 42), "SECTOR B // CROSSFIRE BAY", Color(0.58, 0.90, 1.0, 0.46))
    _add_world_label(Vector2(982, 42), "SECTOR C // TRANSFER SHAFT", Color(0.82, 0.64, 1.0, 0.46))
    _add_world_label(Vector2(1450, 42), "SECTOR D // PURGE LINE", Color(1.0, 0.72, 0.22, 0.46))
    _add_world_label(Vector2(1940, 42), "SECTOR E // KILL FLOOR", Color(0.55, 1.0, 0.32, 0.48))
    _add_world_label(Vector2(2440, 42), "SECTOR F // ROTOR ACCESS", Color(1.0, 0.45, 0.18, 0.52))

func _add_sector_dressing(panel_index: int, theme_index: int):
    var x0 = float(panel_index * 240)

    # Back-wall structural ribs: deliberately behind all collision art.
    for local_x in [18.0, 72.0, 126.0, 180.0, 226.0]:
        var rib = Polygon2D.new()
        rib.polygon = PackedVector2Array([
            Vector2(x0 + local_x, 18),
            Vector2(x0 + local_x + 4, 18),
            Vector2(x0 + local_x + 4, 134),
            Vector2(x0 + local_x, 134)
        ])
        rib.color = _theme_accent(theme_index, 0.10)
        rib.z_index = -32
        add_child(rib)

    match theme_index:
        0:
            _add_background_tank(x0 + 162, 44, 34, 72, Color(0.30, 1.0, 0.22, 0.18))
            _add_warning_lights(x0 + 32, 5, Color(0.35, 1.0, 0.30, 0.38))
        1:
            _add_pipe_bank(x0 + 20, 28, 150, Color(0.28, 0.66, 1.0, 0.18))
            _add_warning_lights(x0 + 192, 4, Color(0.40, 0.78, 1.0, 0.42))
        2:
            _add_background_tank(x0 + 28, 34, 42, 82, Color(0.72, 0.34, 1.0, 0.17))
            _add_background_tank(x0 + 170, 54, 28, 62, Color(0.72, 0.34, 1.0, 0.14))
            _add_warning_lights(x0 + 102, 4, Color(0.82, 0.48, 1.0, 0.38))
        3:
            _add_pipe_bank(x0 + 18, 32, 180, Color(1.0, 0.46, 0.14, 0.15))
            _add_warning_lights(x0 + 36, 6, Color(1.0, 0.36, 0.12, 0.46))
        4:
            _add_background_tank(x0 + 142, 36, 48, 84, Color(0.26, 1.0, 0.20, 0.20))
            _add_warning_lights(x0 + 24, 5, Color(0.40, 1.0, 0.26, 0.46))
        5:
            _add_pipe_bank(x0 + 16, 24, 190, Color(1.0, 0.34, 0.12, 0.18))
            _add_warning_lights(x0 + 42, 7, Color(1.0, 0.30, 0.10, 0.50))

func _theme_accent(theme_index: int, alpha: float):
    var base = theme_tints[theme_index]
    return Color(base.r, base.g, base.b, alpha)

func _add_background_tank(x: float, y: float, width: float, height: float, fluid_color: Color):
    var shell = Polygon2D.new()
    shell.polygon = PackedVector2Array([
        Vector2(x, y + 6), Vector2(x + 5, y), Vector2(x + width - 5, y),
        Vector2(x + width, y + 6), Vector2(x + width, y + height - 6),
        Vector2(x + width - 5, y + height), Vector2(x + 5, y + height),
        Vector2(x, y + height - 6)
    ])
    shell.color = Color(0.03, 0.07, 0.065, 0.70)
    shell.z_index = -31
    add_child(shell)

    var fluid = Polygon2D.new()
    fluid.polygon = PackedVector2Array([
        Vector2(x + 5, y + 10), Vector2(x + width - 5, y + 10),
        Vector2(x + width - 5, y + height - 8), Vector2(x + 5, y + height - 8)
    ])
    fluid.color = fluid_color
    fluid.z_index = -30
    add_child(fluid)

    var glass = Line2D.new()
    glass.points = PackedVector2Array([
        Vector2(x + 4, y + 8), Vector2(x + width - 4, y + 8),
        Vector2(x + width - 4, y + height - 7), Vector2(x + 4, y + height - 7),
        Vector2(x + 4, y + 8)
    ])
    glass.width = 1.0
    glass.default_color = Color(0.55, 0.95, 0.78, 0.22)
    glass.z_index = -29
    add_child(glass)

func _add_pipe_bank(x: float, y: float, width: float, pipe_color: Color):
    for row in range(4):
        var line = Line2D.new()
        line.points = PackedVector2Array([
            Vector2(x, y + row * 11),
            Vector2(x + width * 0.42, y + row * 11),
            Vector2(x + width * 0.52, y + row * 11 + 7),
            Vector2(x + width, y + row * 11 + 7)
        ])
        line.width = 3.0
        line.default_color = pipe_color
        line.z_index = -31
        add_child(line)

func _add_warning_lights(x: float, count: int, color: Color):
    for index in range(count):
        var light = Polygon2D.new()
        var lx = x + index * 24.0
        light.polygon = PackedVector2Array([
            Vector2(lx, 23), Vector2(lx + 5, 23),
            Vector2(lx + 5, 27), Vector2(lx, 27)
        ])
        light.color = color
        light.z_index = -26
        add_child(light)

func _build_geometry():
    # Collision dimensions remain the proven v0.6 geometry. The verified 16px tile
    # strip only changes the foreground appearance.
    tile_texture = load(PROD_TILES)
    super._build_geometry()

func _spawn_gameplay():
    player = PlayerV07.new()
    player.setup(GameState.selected_character)
    player.global_position = GameState.stage_start_position
    add_child(player)
    player.died.connect(_on_player_died)
    player.camera.limit_right = int(STAGE_LENGTH)
    player.camera.limit_bottom = 160

    _spawn_enemy_on_surface(188, 136, -1)
    _spawn_acid_spitter_on_surface(420, 136, -1)

    _spawn_enemy_on_surface(548, 136, -1, 1)
    _spawn_enemy_on_surface(654, 96, 1, 1)

    _spawn_enemy_on_surface(914, 88, -1)
    _spawn_acid_spitter_on_surface(1120, 104, -1)
    _spawn_enemy_on_surface(1238, 104, 1)
    _spawn_enemy_on_surface(1408, 136, -1)

    _spawn_enemy_on_surface(1528, 136, 1, 2)
    _spawn_enemy_on_surface(1632, 104, -1, 2)

    _spawn_acid_spitter_on_surface(1872, 96, -1)
    _spawn_enemy_on_surface(2068, 104, 1)

    _spawn_enemy_on_surface(2208, 136, 1, 3)
    _spawn_enemy_on_surface(2300, 88, -1, 3)
    _spawn_enemy_on_surface(2364, 112, -1, 3, true)

    _spawn_acid_spitter_on_surface(2528, 136, 1)

    var pickup = WeaponPickupV07.new()
    pickup.global_position = Vector2(656, 72)
    add_child(pickup)

    _spawn_checkpoint(Vector2(740, 118), Vector2(752, 118))
    _spawn_checkpoint(Vector2(1452, 118), Vector2(1468, 118))
    _spawn_checkpoint(Vector2(2418, 118), Vector2(2432, 118))

    _spawn_boss()

func _spawn_acid_spitter_on_surface(x: float, surface_y: float, initial_direction: int = -1, wave_id: int = 0):
    var enemy = AcidSpitter.new()
    enemy.patrol_direction = initial_direction
    enemy.global_position = Vector2(x, surface_y - 12.0)
    enemy.defeated.connect(_on_enemy_defeated.bind(wave_id))
    add_child(enemy)
    if wave_id > 0:
        wave_counts[wave_id] = int(wave_counts[wave_id]) + 1
    return enemy
