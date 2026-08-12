extends CharacterBody2D

signal defeated(boss)
signal health_changed(current_hp, max_hp)

const HealthComponent = preload("res://scripts/components/health_component.gd")
const GameRules = preload("res://scripts/data/game_rules.gd")
const Projectile = preload("res://scripts/weapons/projectile.gd")

var arena_min_x = 2664.0
var arena_max_x = 2848.0
var active = false
var dead = false
var phase = 1
var attack_timer = 0.90
var windup_timer = 0.0
var move_direction = -1
var sprite
var health
var damage_area
var phase_flash = 0.0

func setup(min_x: float, max_x: float):
    arena_min_x = min_x
    arena_max_x = max_x

func _ready():
    add_to_group("enemies")
    add_to_group("bosses")
    collision_layer = 4
    collision_mask = 1

    var collider = CollisionShape2D.new()
    var body_shape = RectangleShape2D.new()
    body_shape.size = Vector2(38, 28)
    collider.shape = body_shape
    collider.position = Vector2(0, -14)
    add_child(collider)

    sprite = Sprite2D.new()
    sprite.texture = load("res://assets/bosses/killing_floor_rotor.png")
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = Vector2(0, -27)
    # The CI-safe production asset is 75% of the source dimensions; this scale
    # preserves the intended ~65px boss silhouette at the 240x160 game view.
    sprite.scale = Vector2(0.39, 0.39)
    add_child(sprite)

    health = HealthComponent.new()
    health.configure(_boss_hp(), 0.06)
    add_child(health)
    health.health_changed.connect(_on_health_changed)
    health.died.connect(_on_died)

    damage_area = Area2D.new()
    damage_area.collision_layer = 32
    damage_area.collision_mask = 2
    var damage_shape = CollisionShape2D.new()
    var area_shape = RectangleShape2D.new()
    area_shape.size = Vector2(42, 31)
    damage_shape.shape = area_shape
    damage_shape.position = Vector2(0, -14)
    damage_area.add_child(damage_shape)
    add_child(damage_area)
    damage_area.body_entered.connect(_on_damage_area_body_entered)

    set_active(false)

func _boss_hp():
    match GameState.difficulty:
        "easy": return 42
        "hard": return 56
        "nightmare": return 64
        _: return 48

func set_active(value: bool):
    active = value
    if sprite != null:
        sprite.modulate = Color.WHITE if active else Color(0.58, 0.68, 0.62, 1.0)

func _physics_process(delta):
    if dead:
        return
    if not active:
        velocity = Vector2.ZERO
        return

    if not is_on_floor():
        velocity.y += GameRules.GRAVITY * delta

    var player = get_tree().get_first_node_in_group("players")
    if player == null or player.dead:
        velocity.x = 0.0
        move_and_slide()
        return

    _update_phase()
    attack_timer = max(0.0, attack_timer - delta)
    phase_flash = max(0.0, phase_flash - delta)

    if windup_timer > 0.0:
        windup_timer = max(0.0, windup_timer - delta)
        velocity.x = 0.0
        sprite.modulate = Color(0.56, 1.0, 0.38, 1.0)
        if windup_timer <= 0.0:
            _fire_pattern(player)
    else:
        sprite.modulate = Color(1.0, 0.84, 0.74, 1.0) if phase_flash > 0.0 else Color.WHITE
        _update_movement(player)
        if attack_timer <= 0.0:
            _start_windup()

    move_and_slide()
    global_position.x = clamp(global_position.x, arena_min_x, arena_max_x)
    sprite.flip_h = player.global_position.x < global_position.x

func _update_phase():
    var ratio = float(health.current_hp) / float(max(1, health.max_hp))
    var next_phase = 1
    if ratio <= 0.34:
        next_phase = 3
    elif ratio <= 0.67:
        next_phase = 2
    if next_phase != phase:
        phase = next_phase
        phase_flash = 0.45
        attack_timer = 0.28

func _update_movement(player):
    var dx = player.global_position.x - global_position.x
    var distance_x = abs(dx)
    var dir_to_player = int(sign(dx))
    if dir_to_player == 0:
        dir_to_player = move_direction

    var speed = 34.0
    if phase == 2:
        speed = 42.0
    elif phase == 3:
        speed = 50.0

    if distance_x < 72.0:
        velocity.x = -dir_to_player * speed
    elif distance_x > 122.0:
        velocity.x = dir_to_player * speed * 0.72
    else:
        # Strafe rather than becoming a stationary turret.
        if global_position.x <= arena_min_x + 10.0:
            move_direction = 1
        elif global_position.x >= arena_max_x - 10.0:
            move_direction = -1
        velocity.x = move_direction * speed * (0.46 if phase < 3 else 0.62)

func _start_windup():
    windup_timer = 0.26 if phase == 1 else (0.22 if phase == 2 else 0.18)
    velocity.x = 0.0

func _fire_pattern(player):
    var origin = global_position + Vector2(-20.0 if sprite.flip_h else 20.0, -26.0)
    var target = player.global_position + Vector2(0, -10)
    var base_direction = (target - origin).normalized()

    if phase == 1:
        _spawn_projectile(origin, base_direction, 132.0, 1)
        attack_timer = 0.92
    elif phase == 2:
        for angle in [-0.16, 0.0, 0.16]:
            _spawn_projectile(origin, base_direction.rotated(float(angle)), 142.0, 1)
        attack_timer = 0.74
    else:
        for angle in [-0.30, -0.15, 0.0, 0.15, 0.30]:
            _spawn_projectile(origin, base_direction.rotated(float(angle)), 154.0, 1)
        attack_timer = 0.58
        # Phase 3 also reverses its strafe after every burst so the player must reposition.
        move_direction *= -1

func _spawn_projectile(origin: Vector2, direction: Vector2, speed: float, damage: int):
    var projectile = Projectile.new()
    projectile.setup(direction, speed, damage, "enemy")
    get_tree().current_scene.add_child(projectile)
    projectile.global_position = origin

func take_damage(amount, source_position = Vector2.ZERO):
    if dead or not active:
        return false
    if health.damage(amount):
        var knock = sign(global_position.x - source_position.x)
        if knock == 0.0:
            knock = 1.0
        velocity.x += knock * 12.0
        sprite.modulate = Color(1.0, 1.0, 1.0, 0.48)
        var tween = create_tween()
        tween.tween_property(sprite, "modulate", Color.WHITE, 0.09)
        return true
    return false

func _on_health_changed(current_hp, max_hp):
    health_changed.emit(current_hp, max_hp)

func _on_damage_area_body_entered(body):
    if active and not dead and body.is_in_group("players") and body.has_method("take_damage"):
        body.take_damage(2, global_position)

func _on_died():
    if dead:
        return
    dead = true
    active = false
    collision_layer = 0
    collision_mask = 0
    if damage_area != null:
        damage_area.set_deferred("monitoring", false)
        damage_area.set_deferred("monitorable", false)
    GameState.register_enemy_kill(1500)
    var tween = create_tween()
    tween.tween_property(sprite, "scale", Vector2(0.47, 0.29), 0.10)
    tween.tween_property(sprite, "modulate", Color(0.35, 1.0, 0.28, 0.0), 0.38)
    tween.finished.connect(_finish_death)

func _finish_death():
    defeated.emit(self)
    queue_free()
