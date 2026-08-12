extends "res://scripts/scenes/stage1_killing_floor.gd"

const PlayerV06 = preload("res://scripts/actors/player_v06.gd")
const LadderV06 = preload("res://scripts/world/ladder.gd")
const WeaponPickupV06 = preload("res://scripts/world/weapon_pickup.gd")

func _build_background():
    # Keep the stable parallax/panel foundation, then break up the repeated-wall look
    # with room-specific industrial silhouettes, pipes, vats, fans and practical lights.
    super._build_background()

    for panel_index in range(12):
        _decorate_sector_panel(panel_index)

    # Long utility trunks visually connect the whole facility rather than making each
    # 240 px screen read as a disconnected wallpaper tile.
    _bg_line(PackedVector2Array([Vector2(0, 28), Vector2(STAGE_LENGTH, 28)]), 4.0, Color(0.025, 0.055, 0.052, 0.88), -25)
    _bg_line(PackedVector2Array([Vector2(0, 31), Vector2(STAGE_LENGTH, 31)]), 1.0, Color(0.28, 0.55, 0.36, 0.28), -24)
    _bg_line(PackedVector2Array([Vector2(0, 131), Vector2(STAGE_LENGTH, 131)]), 3.0, Color(0.018, 0.035, 0.032, 0.92), -25)

func _decorate_sector_panel(panel_index: int):
    var x0 = float(panel_index * 240)
    var theme = min(5, int(panel_index / 2))

    # Structural ribs establish scale and make collision platforms look supported by
    # the same architecture rather than pasted over a flat image.
    for local_x in [12.0, 66.0, 120.0, 174.0, 228.0]:
        _bg_rect(Rect2(x0 + local_x - 2.0, 18, 4, 116), Color(0.025, 0.050, 0.047, 0.72), -25)
        _bg_line(PackedVector2Array([
            Vector2(x0 + local_x - 1.0, 22),
            Vector2(x0 + local_x - 1.0, 132)
        ]), 1.0, Color(0.25, 0.48, 0.34, 0.18), -24)

    _bg_rect(Rect2(x0 + 5, 34, 230, 8), Color(0.018, 0.038, 0.036, 0.82), -25)
    _bg_line(PackedVector2Array([Vector2(x0 + 8, 38), Vector2(x0 + 232, 38)]), 1.0, Color(0.30, 0.58, 0.38, 0.18), -24)

    match theme:
        0:
            _add_vat(x0 + 28, 58, 46, 68, Color(0.27, 0.95, 0.20, 0.16))
            _add_console(x0 + 136, 83, 52, 39, Color(0.35, 1.0, 0.23, 0.34))
            _add_warning_lamp(Vector2(x0 + 210, 52), Color(0.35, 1.0, 0.22, 0.55))
        1:
            _add_fan(Vector2(x0 + 54, 77), 27.0)
            _add_console(x0 + 126, 70, 76, 50, Color(0.90, 0.45, 0.12, 0.34))
            _add_warning_lamp(Vector2(x0 + 218, 54), Color(1.0, 0.38, 0.10, 0.64))
        2:
            _add_lift_shaft_background(x0 + 78, 46, 84, 84)
            _add_console(x0 + 176, 88, 45, 33, Color(0.32, 0.92, 0.22, 0.30))
        3:
            _add_vat(x0 + 23, 58, 43, 70, Color(0.28, 1.0, 0.18, 0.22))
            _add_vat(x0 + 83, 51, 47, 77, Color(0.28, 1.0, 0.18, 0.17))
            _add_pipe_cluster(x0 + 157, 52)
        4:
            _add_fan(Vector2(x0 + 60, 72), 24.0)
            _add_pipe_cluster(x0 + 112, 49)
            _add_console(x0 + 165, 84, 57, 37, Color(1.0, 0.32, 0.10, 0.31))
            _add_warning_lamp(Vector2(x0 + 218, 52), Color(1.0, 0.27, 0.08, 0.72))
        _:
            _add_rotor_core_background(Vector2(x0 + 120, 79))
            _add_warning_lamp(Vector2(x0 + 32, 51), Color(1.0, 0.24, 0.07, 0.74))
            _add_warning_lamp(Vector2(x0 + 208, 51), Color(1.0, 0.24, 0.07, 0.74))

func _build_geometry():
    super._build_geometry()

    # Real ladder routes. Ladders sit beside platform edges instead of passing through
    # solid collision, so the player can mount, climb, and step onto the upper surface.
    # Room 4 maintenance climb.
    _add_ladder(812, 104, 136, 1)
    _add_ladder(880, 88, 104, 1)

    # Room 6 toxic sluice alternate vertical route.
    _add_ladder(1216, 104, 136, 1)
    _add_ladder(1280, 88, 104, 1)
    _add_ladder(1406, 104, 136, -1)

    # Room 8 trench high route.
    _add_ladder(1694, 96, 136, 1)
    _add_ladder(1766, 80, 96, 1)
    _add_ladder(1906, 96, 136, -1)

    # Room 9 descending stack entry.
    _add_ladder(1966, 88, 136, 1)

    # Room 11 pre-boss maintenance route.
    _add_ladder(2424, 104, 136, 1)
    _add_ladder(2488, 88, 104, 1)

    # Boss arena high-ground options. They are tactical, never mandatory.
    _add_ladder(2720, 96, 136, -1)
    _add_ladder(2800, 96, 136, 1)

    # Route lights communicate climbable vertical paths at phone scale.
    for marker in [
        Vector2(812, 101), Vector2(880, 85), Vector2(1216, 101), Vector2(1280, 85),
        Vector2(1406, 101), Vector2(1694, 93), Vector2(1766, 77), Vector2(1906, 93),
        Vector2(1966, 85), Vector2(2424, 101), Vector2(2488, 85),
        Vector2(2720, 93), Vector2(2800, 93)
    ]:
        _add_route_beacon(marker)

func _spawn_gameplay():
    # Ground/air handling is inherited unchanged from the stable v0.5 player; the
    # subclass only adds ladder states and uses the already-shipped climb frames.
    player = PlayerV06.new()
    player.setup(GameState.selected_character)
    player.global_position = GameState.stage_start_position
    add_child(player)
    player.died.connect(_on_player_died)
    player.camera.limit_right = int(STAGE_LENGTH)
    player.camera.limit_bottom = 160

    _spawn_enemy_on_surface(188, 136, -1)
    _spawn_enemy_on_surface(420, 136, -1)

    # Lockdown 1.
    _spawn_enemy_on_surface(548, 136, -1, 1)
    _spawn_enemy_on_surface(654, 96, 1, 1)

    # Keep enemies off ladder mounting/landing zones. Pressure comes from crossfire,
    # not an unavoidable body collision at the end of a climb.
    _spawn_enemy_on_surface(914, 88, -1)
    _spawn_enemy_on_surface(1120, 104, -1)
    _spawn_enemy_on_surface(1238, 104, 1)
    _spawn_enemy_on_surface(1408, 136, -1)

    # Lockdown 2.
    _spawn_enemy_on_surface(1528, 136, 1, 2)
    _spawn_enemy_on_surface(1632, 104, -1, 2)

    _spawn_enemy_on_surface(1872, 96, -1)
    _spawn_enemy_on_surface(2068, 104, 1)

    # Lockdown 3.
    _spawn_enemy_on_surface(2208, 136, 1, 3)
    _spawn_enemy_on_surface(2300, 88, -1, 3)
    _spawn_enemy_on_surface(2364, 112, -1, 3, true)

    _spawn_enemy_on_surface(2528, 136, 1)

    var pickup = WeaponPickupV06.new()
    pickup.global_position = Vector2(656, 72)
    add_child(pickup)

    _spawn_checkpoint(Vector2(740, 118), Vector2(752, 118))
    _spawn_checkpoint(Vector2(1452, 118), Vector2(1468, 118))
    _spawn_checkpoint(Vector2(2418, 118), Vector2(2432, 118))

    _spawn_boss()

func _add_ladder(x_value: float, top_surface_y: float, bottom_surface_y: float, exit_direction: int):
    var ladder = LadderV06.new()
    ladder.setup(x_value, top_surface_y, bottom_surface_y, exit_direction)
    add_child(ladder)

func _add_route_beacon(pos: Vector2):
    _bg_rect(Rect2(pos.x - 2, pos.y - 2, 4, 4), Color(0.42, 1.0, 0.22, 0.42), -1)
    _bg_line(PackedVector2Array([Vector2(pos.x, pos.y + 4), Vector2(pos.x, pos.y + 9)]), 1.0, Color(0.42, 1.0, 0.22, 0.34), -1)

func _bg_rect(rect: Rect2, color: Color, z_value: int):
    var poly = Polygon2D.new()
    poly.polygon = PackedVector2Array([
        rect.position,
        Vector2(rect.end.x, rect.position.y),
        rect.end,
        Vector2(rect.position.x, rect.end.y)
    ])
    poly.color = color
    poly.z_index = z_value
    add_child(poly)
    return poly

func _bg_line(points: PackedVector2Array, width: float, color: Color, z_value: int):
    var line = Line2D.new()
    line.points = points
    line.width = width
    line.default_color = color
    line.z_index = z_value
    add_child(line)
    return line

func _add_vat(x_value: float, y_value: float, width: float, height: float, fluid_color: Color):
    _bg_rect(Rect2(x_value, y_value, width, height), Color(0.018, 0.036, 0.034, 0.88), -23)
    _bg_rect(Rect2(x_value + 5, y_value + 8, width - 10, height - 16), fluid_color, -22)
    _bg_line(PackedVector2Array([
        Vector2(x_value, y_value), Vector2(x_value + width, y_value),
        Vector2(x_value + width, y_value + height), Vector2(x_value, y_value + height),
        Vector2(x_value, y_value)
    ]), 2.0, Color(0.24, 0.41, 0.37, 0.70), -21)
    _bg_line(PackedVector2Array([
        Vector2(x_value + 7, y_value + 15),
        Vector2(x_value + width - 7, y_value + 15)
    ]), 1.0, Color(0.48, 1.0, 0.31, 0.28), -20)

func _add_console(x_value: float, y_value: float, width: float, height: float, screen_color: Color):
    _bg_rect(Rect2(x_value, y_value, width, height), Color(0.025, 0.047, 0.045, 0.88), -23)
    _bg_rect(Rect2(x_value + 5, y_value + 5, width - 10, max(8.0, height * 0.42)), screen_color, -22)
    _bg_line(PackedVector2Array([
        Vector2(x_value + 6, y_value + height - 8),
        Vector2(x_value + width - 6, y_value + height - 8)
    ]), 2.0, Color(0.33, 0.47, 0.42, 0.52), -21)

func _add_warning_lamp(pos: Vector2, lamp_color: Color):
    _bg_rect(Rect2(pos.x - 4, pos.y - 3, 8, 6), Color(0.03, 0.04, 0.035, 0.90), -20)
    _bg_rect(Rect2(pos.x - 2, pos.y - 2, 4, 4), lamp_color, -19)
    _bg_line(PackedVector2Array([Vector2(pos.x, pos.y + 3), Vector2(pos.x, pos.y + 10)]), 1.0, lamp_color * Color(1, 1, 1, 0.42), -20)

func _add_fan(center: Vector2, radius: float):
    _add_bg_ring(center, radius, Color(0.18, 0.30, 0.29, 0.78), -22)
    _add_bg_ring(center, radius * 0.62, Color(0.13, 0.24, 0.23, 0.66), -22)
    for direction in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]:
        var side = Vector2(-direction.y, direction.x)
        var p1 = center + direction * 4.0
        var p2 = center + direction * radius * 0.68 + side * 7.0
        var p3 = center + direction * radius * 0.68 - side * 7.0
        var blade = Polygon2D.new()
        blade.polygon = PackedVector2Array([p1, p2, p3])
        blade.color = Color(0.045, 0.085, 0.080, 0.78)
        blade.z_index = -21
        add_child(blade)
    _bg_rect(Rect2(center.x - 3, center.y - 3, 6, 6), Color(0.31, 0.55, 0.40, 0.46), -20)

func _add_bg_ring(center: Vector2, radius: float, color: Color, z_value: int):
    var points = PackedVector2Array()
    for i in range(17):
        var angle = TAU * float(i) / 16.0
        points.append(center + Vector2(cos(angle), sin(angle)) * radius)
    _bg_line(points, 2.0, color, z_value)

func _add_lift_shaft_background(x_value: float, y_value: float, width: float, height: float):
    _bg_rect(Rect2(x_value, y_value, width, height), Color(0.012, 0.026, 0.025, 0.84), -24)
    for rail_x in [x_value + 14.0, x_value + width - 14.0]:
        _bg_line(PackedVector2Array([Vector2(rail_x, y_value + 3), Vector2(rail_x, y_value + height - 3)]), 3.0, Color(0.16, 0.30, 0.28, 0.72), -22)
        _bg_line(PackedVector2Array([Vector2(rail_x - 1, y_value + 3), Vector2(rail_x - 1, y_value + height - 3)]), 1.0, Color(0.35, 0.58, 0.42, 0.28), -21)
    for rung_y in range(int(y_value + 10), int(y_value + height - 4), 12):
        _bg_line(PackedVector2Array([Vector2(x_value + 15, rung_y), Vector2(x_value + width - 15, rung_y)]), 1.0, Color(0.17, 0.31, 0.29, 0.52), -22)

func _add_pipe_cluster(x_value: float, y_value: float):
    for offset in [0.0, 10.0, 20.0]:
        _bg_line(PackedVector2Array([
            Vector2(x_value + offset, y_value),
            Vector2(x_value + offset, 117),
            Vector2(x_value + 44 + offset * 0.25, 117)
        ]), 3.0, Color(0.05, 0.10, 0.095, 0.84), -23)
        _bg_line(PackedVector2Array([
            Vector2(x_value + offset - 0.5, y_value + 2),
            Vector2(x_value + offset - 0.5, 115)
        ]), 1.0, Color(0.27, 0.43, 0.34, 0.24), -22)

func _add_rotor_core_background(center: Vector2):
    _add_bg_ring(center, 43.0, Color(0.18, 0.28, 0.26, 0.72), -23)
    _add_bg_ring(center, 32.0, Color(0.31, 0.42, 0.31, 0.54), -22)
    _add_bg_ring(center, 20.0, Color(0.52, 0.24, 0.10, 0.46), -21)
    _bg_rect(Rect2(center.x - 7, center.y - 7, 14, 14), Color(0.85, 0.22, 0.07, 0.28), -20)
    for direction in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]:
        _bg_line(PackedVector2Array([
            center + direction * 12.0,
            center + direction * 40.0
        ]), 4.0, Color(0.045, 0.070, 0.065, 0.82), -21)
