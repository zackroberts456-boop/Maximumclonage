extends "res://scripts/scenes/stage1_killing_floor_v06.gd"

const PlayerV07 = preload("res://scripts/actors/player_v06.gd")
const AcidSpitter = preload("res://scripts/actors/acid_spitter.gd")
const WeaponPickupV07 = preload("res://scripts/world/weapon_pickup.gd")

const PROD_BACKGROUND = "res://assets/environment/lab_environment_prod_v2.png"
const PROD_TILES = "res://assets/environment/lab_tiles_prod_16.png"

func _build_background():
    # v0.7 swaps the repeated wallpaper foundation for six authored laboratory themes.
    # Each theme occupies a 240x160 slice and is repeated for two adjacent rooms so
    # areas feel coherent without every screen looking identical.
    var production_atlas = load(PROD_BACKGROUND)
    for panel_index in range(12):
        var theme_index = min(5, int(panel_index / 2))
        var atlas = AtlasTexture.new()
        atlas.atlas = production_atlas
        atlas.region = Rect2(0, theme_index * 160, 240, 160)

        var panel = Sprite2D.new()
        panel.texture = atlas
        panel.centered = false
        panel.position = Vector2(panel_index * 240, 0)
        panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        panel.z_index = -40
        add_child(panel)

        # Subtle room seam keeps the 240px design language readable while remaining
        # far less obvious than the old repeated-background boundary.
        if panel_index > 0:
            var seam = Line2D.new()
            seam.points = PackedVector2Array([
                Vector2(panel_index * 240, 18),
                Vector2(panel_index * 240, 134)
            ])
            seam.width = 1.0
            seam.default_color = Color(0.24, 0.56, 0.31, 0.12)
            seam.z_index = -30
            add_child(seam)

    # Low-opacity atmosphere keeps the foreground and enemies readable on a phone.
    var depth_tint = Polygon2D.new()
    depth_tint.polygon = PackedVector2Array([
        Vector2(0, 0), Vector2(STAGE_LENGTH, 0),
        Vector2(STAGE_LENGTH, 160), Vector2(0, 160)
    ])
    depth_tint.color = Color(0.0, 0.035, 0.025, 0.09)
    depth_tint.z_index = -29
    add_child(depth_tint)

    _add_world_label(Vector2(18, 42), "SECTOR A // ENTRY LINE", Color(0.55, 1.0, 0.32, 0.46))
    _add_world_label(Vector2(492, 42), "SECTOR B // CROSSFIRE BAY", Color(0.55, 1.0, 0.32, 0.43))
    _add_world_label(Vector2(982, 42), "SECTOR C // TRANSFER SHAFT", Color(0.55, 1.0, 0.32, 0.43))
    _add_world_label(Vector2(1450, 42), "SECTOR D // PURGE LINE", Color(1.0, 0.72, 0.22, 0.45))
    _add_world_label(Vector2(1940, 42), "SECTOR E // KILL FLOOR", Color(1.0, 0.55, 0.20, 0.48))
    _add_world_label(Vector2(2440, 42), "SECTOR F // ROTOR ACCESS", Color(1.0, 0.42, 0.16, 0.52))

func _build_geometry():
    # All collision dimensions remain the proven v0.6 geometry. Only the foreground
    # tile art changes, keeping the platforming feel locked while raising fidelity.
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

    # Room 1 teaches the familiar grunt. Room 2 safely introduces the Acid Spitter's
    # visible arc and puddle before the stage asks the player to handle it near hazards.
    _spawn_enemy_on_surface(188, 136, -1)
    _spawn_acid_spitter_on_surface(420, 136, -1)

    # Lockdown 1 stays grunt-only so its existing crossfire rhythm remains intact.
    _spawn_enemy_on_surface(548, 136, -1, 1)
    _spawn_enemy_on_surface(654, 96, 1, 1)

    _spawn_enemy_on_surface(914, 88, -1)
    _spawn_acid_spitter_on_surface(1120, 104, -1)
    _spawn_enemy_on_surface(1238, 104, 1)
    _spawn_enemy_on_surface(1408, 136, -1)

    # Lockdown 2 remains a clean strafing test, not an acid-puddle traffic jam.
    _spawn_enemy_on_surface(1528, 136, 1, 2)
    _spawn_enemy_on_surface(1632, 104, -1, 2)

    # One elevated spitter creates a readable trench arc while ladders/moving routes
    # still provide multiple answers to the encounter.
    _spawn_acid_spitter_on_surface(1872, 96, -1)
    _spawn_enemy_on_surface(2068, 104, 1)

    # Lockdown 3 preserves the established three-point grunt crossfire and elite.
    _spawn_enemy_on_surface(2208, 136, 1, 3)
    _spawn_enemy_on_surface(2300, 88, -1, 3)
    _spawn_enemy_on_surface(2364, 112, -1, 3, true)

    # Final non-boss enemy is a spitter so the player has one last pattern check before
    # the Rotor arena, with the nearby checkpoint preventing tedious repetition.
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
