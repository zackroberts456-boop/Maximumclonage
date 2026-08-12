extends "res://scripts/scenes/stage1_killing_floor_v07.gd"

const HealthPickup = preload("res://scripts/world/health_pickup.gd")

const RESPAWN_ARM_DISTANCE = 300.0
const RESPAWN_TRIGGER_DISTANCE = 205.0
const RESPAWN_SAFE_DISTANCE = 92.0

var common_spawns = []

func _process(delta):
    super._process(delta)
    if stage_complete or player == null or player.dead:
        return
    _update_common_enemy_respawns()

func _spawn_gameplay():
    common_spawns.clear()

    player = PlayerV07.new()
    player.setup(GameState.selected_character)
    player.global_position = GameState.stage_start_position
    add_child(player)
    player.died.connect(_on_player_died)
    player.camera.limit_right = int(STAGE_LENGTH)
    player.camera.limit_bottom = 160

    # Common enemies now obey Mega Man-style backtracking respawn rules. Lockdown
    # enemies and the elite are deliberately excluded so combat gates stay meaningful.
    _spawn_common_grunt(188, 136, -1)
    _spawn_common_acid(420, 136, -1)

    _spawn_enemy_on_surface(548, 136, -1, 1)
    _spawn_enemy_on_surface(654, 96, 1, 1)

    _spawn_common_grunt(914, 88, -1)
    _spawn_common_acid(1120, 104, -1)
    _spawn_common_grunt(1238, 104, 1)
    _spawn_common_grunt(1408, 136, -1)

    _spawn_enemy_on_surface(1528, 136, 1, 2)
    _spawn_enemy_on_surface(1632, 104, -1, 2)

    _spawn_common_acid(1872, 96, -1)
    _spawn_common_grunt(2068, 104, 1)

    _spawn_enemy_on_surface(2208, 136, 1, 3)
    _spawn_enemy_on_surface(2300, 88, -1, 3)
    _spawn_enemy_on_surface(2364, 112, -1, 3, true)

    _spawn_common_acid(2528, 136, 1)

    var pickup = WeaponPickupV07.new()
    pickup.global_position = Vector2(656, 72)
    add_child(pickup)

    # Health rewards favor optional elevation and controlled detours instead of being
    # sprayed across the main path. Small = +2, large = +5, full = rare full restore.
    _spawn_health_pickup(Vector2(400, 84), HealthPickup.KIND_SMALL)
    _spawn_health_pickup(Vector2(1106, 76), HealthPickup.KIND_LARGE)
    _spawn_health_pickup(Vector2(1760, 84), HealthPickup.KIND_SMALL)
    _spawn_health_pickup(Vector2(2288, 62), HealthPickup.KIND_LARGE)
    _spawn_health_pickup(Vector2(2484, 76), HealthPickup.KIND_FULL)

    _spawn_checkpoint(Vector2(740, 118), Vector2(752, 118))
    _spawn_checkpoint(Vector2(1452, 118), Vector2(1468, 118))
    _spawn_checkpoint(Vector2(2418, 118), Vector2(2432, 118))

    _spawn_boss()

func _spawn_health_pickup(pos: Vector2, kind: String):
    var pickup = HealthPickup.new()
    pickup.setup(kind)
    pickup.global_position = pos
    add_child(pickup)
    return pickup

func _spawn_common_grunt(x: float, surface_y: float, initial_direction: int):
    var spawn_id = common_spawns.size()
    var descriptor = {
        "type": "grunt",
        "x": x,
        "surface_y": surface_y,
        "direction": initial_direction,
        "active": true,
        "armed": false,
        "node": null
    }
    common_spawns.append(descriptor)
    var enemy = _spawn_enemy_on_surface(x, surface_y, initial_direction)
    enemy.defeated.connect(_on_common_enemy_defeated.bind(spawn_id))
    common_spawns[spawn_id]["node"] = enemy
    return enemy

func _spawn_common_acid(x: float, surface_y: float, initial_direction: int):
    var spawn_id = common_spawns.size()
    var descriptor = {
        "type": "acid",
        "x": x,
        "surface_y": surface_y,
        "direction": initial_direction,
        "active": true,
        "armed": false,
        "node": null
    }
    common_spawns.append(descriptor)
    var enemy = _spawn_acid_spitter_on_surface(x, surface_y, initial_direction)
    enemy.defeated.connect(_on_common_enemy_defeated.bind(spawn_id))
    common_spawns[spawn_id]["node"] = enemy
    return enemy

func _on_common_enemy_defeated(_enemy, spawn_id: int):
    if spawn_id < 0 or spawn_id >= common_spawns.size():
        return
    common_spawns[spawn_id]["active"] = false
    common_spawns[spawn_id]["armed"] = false
    common_spawns[spawn_id]["node"] = null

func _update_common_enemy_respawns():
    for spawn_id in range(common_spawns.size()):
        var descriptor = common_spawns[spawn_id]
        var enemy = descriptor["node"]

        if bool(descriptor["active"]):
            if enemy == null or not is_instance_valid(enemy):
                descriptor["active"] = false
                descriptor["armed"] = false
                descriptor["node"] = null
                common_spawns[spawn_id] = descriptor
            continue

        var distance_x = abs(player.global_position.x - float(descriptor["x"]))
        if distance_x >= RESPAWN_ARM_DISTANCE:
            descriptor["armed"] = true
            common_spawns[spawn_id] = descriptor
            continue

        # Recreate the enemy before its spawn point scrolls fully back on screen, but
        # never directly on top of the player. This reproduces the useful Mega Man
        # backtracking behavior without cheap pop-in damage.
        if bool(descriptor["armed"]) and distance_x <= RESPAWN_TRIGGER_DISTANCE and distance_x >= RESPAWN_SAFE_DISTANCE:
            _respawn_common_enemy(spawn_id)

func _respawn_common_enemy(spawn_id: int):
    if spawn_id < 0 or spawn_id >= common_spawns.size():
        return
    var descriptor = common_spawns[spawn_id]
    var enemy
    if String(descriptor["type"]) == "acid":
        enemy = _spawn_acid_spitter_on_surface(
            float(descriptor["x"]),
            float(descriptor["surface_y"]),
            int(descriptor["direction"])
        )
    else:
        enemy = _spawn_enemy_on_surface(
            float(descriptor["x"]),
            float(descriptor["surface_y"]),
            int(descriptor["direction"])
        )

    enemy.defeated.connect(_on_common_enemy_defeated.bind(spawn_id))
    descriptor["node"] = enemy
    descriptor["active"] = true
    descriptor["armed"] = false
    common_spawns[spawn_id] = descriptor
