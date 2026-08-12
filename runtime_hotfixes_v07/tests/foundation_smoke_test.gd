extends SceneTree

const GameRules = preload("res://scripts/data/game_rules.gd")
const CharacterDatabase = preload("res://scripts/data/character_database.gd")

var failures = []

func _initialize():
    _check(GameRules.INTERNAL_RESOLUTION == Vector2i(240, 160), "internal resolution")
    _check(GameRules.DIFFICULTIES["normal"]["hp"] == 12, "normal HP")
    _check(GameRules.DIFFICULTIES["normal"]["lives"] == 3, "normal lives")
    _check(GameRules.PLAYER_INVULNERABILITY == 1.0, "damage invulnerability")
    _check(GameRules.COYOTE_TIME > 0.0, "coyote time")
    _check(GameRules.JUMP_BUFFER_TIME > 0.0, "jump buffer")
    _check(CharacterDatabase.get_order().size() == 6, "six-character roster")

    for path in [
        "res://scenes/boot.tscn",
        "res://scenes/title_screen.tscn",
        "res://scenes/character_select.tscn",
        "res://scenes/stage1_killing_floor.tscn",
        "res://scenes/test_room.tscn",
        "res://scripts/actors/player.gd",
        "res://scripts/actors/player_v06.gd",
        "res://scripts/actors/test_enemy.gd",
        "res://scripts/actors/acid_spitter.gd",
        "res://scripts/actors/killing_floor_rotor.gd",
        "res://scripts/weapons/acid_glob.gd",
        "res://scripts/world/acid_puddle.gd",
        "res://scripts/world/ladder.gd",
        "res://scripts/scenes/stage1_killing_floor.gd",
        "res://scripts/scenes/stage1_killing_floor_v06.gd",
        "res://scripts/scenes/stage1_killing_floor_v07.gd",
        "res://scripts/ui/hud.gd",
        "res://scripts/ui/touch_controls.gd",
        "res://assets/bosses/killing_floor_rotor.png",
        "res://assets/enemies/clone_grunt_idle.png",
        "res://assets/enemies/acid_spitter_production.png",
        "res://assets/environment/lab_panel_240x160.png",
        "res://assets/environment/lab_tiles_prod_16.png"
    ]:
        _check(ResourceLoader.exists(path), "resource exists: %s" % path)
        if ResourceLoader.exists(path):
            _check(load(path) != null, "resource parses/loads: %s" % path)

    _check_texture_size("res://assets/enemies/acid_spitter_production.png", Vector2(224, 224), "production Acid Spitter dimensions")
    _check_texture_size("res://assets/environment/lab_tiles_prod_16.png", Vector2(128, 16), "production lab tile dimensions")

    if failures.is_empty():
        print("MAXIMUM CLONAGE FOUNDATION SMOKE TEST: PASS")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("MAXIMUM CLONAGE FOUNDATION SMOKE TEST: FAIL (%d)" % failures.size())
        quit(1)

func _check_texture_size(path: String, expected_size: Vector2, description: String):
    if not ResourceLoader.exists(path):
        failures.append(description)
        return
    var texture = load(path)
    if texture == null or not texture.has_method("get_size"):
        failures.append(description)
        return
    _check(texture.get_size() == expected_size, description)

func _check(condition, description):
    if not condition:
        failures.append(description)
