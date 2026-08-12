extends SceneTree

func _initialize():
    var enemy_script = load("res://scripts/actors/test_enemy.gd")
    if enemy_script == null:
        push_error("Enemy script failed to load")
        quit(1)
        return
    var enemy = enemy_script.new()
    if enemy == null:
        push_error("Enemy could not be instantiated")
        quit(1)
        return
    if not ("patrol_direction" in enemy):
        push_error("Enemy AI patrol state missing")
        quit(1)
        return
    print("MAXIMUM CLONAGE ENEMY AI SMOKE TEST: PASS")
    quit(0)
