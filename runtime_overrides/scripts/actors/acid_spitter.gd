extends CharacterBody2D

signal defeated(enemy)

const HealthComponent = preload("res://scripts/components/health_component.gd")
const GameRules = preload("res://scripts/data/game_rules.gd")
const AcidGlob = preload("res://scripts/weapons/acid_glob.gd")

const ACTIVATION_RANGE = 230.0
const PATROL_RADIUS = 70.0
const RETREAT_RANGE = 58.0
const SPIT_MIN_RANGE = 72.0
const SPIT_MAX_RANGE = 176.0
const SPRITE_REST_Y = -32.0

var spawn_x = 0.0
var patrol_direction = -1
var speed = 24.0
var spit_interval = 1.42
var spit_timer = 0.55
var windup_left = 0.0
var recoil_left = 0.0
var dead = false
var health
var sprite
var damage_area
var walk_phase = 0.0
var current_state = "patrol"

func _ready():
    add_to_group("enemies")
    add_to_group("acid_spitters")
    collision_layer = 4
    collision_mask = 1
    spawn_x = global_position.x

    var difficulty = GameRules.difficulty_data(GameState.difficulty)
    speed *= float(difficulty["enemy_speed_scale"])
    spit_interval *= float(difficulty["enemy_fire_interval_scale"])

    var collider = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(20, 30)
    collider.shape = shape
    collider.position = Vector2(0, -3)
    add_child(collider)

    sprite = Sprite2D.new()
    sprite.texture = load("res://assets/enemies/acid_spitter_production.png")
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.scale = Vector2(0.30, 0.30)
    sprite.position = Vector2(0, SPRITE_REST_Y)
    add_child(sprite)

    health = HealthComponent.new()
    health.configure(_max_hp_for_difficulty(), 0.11)
    add_child(health)
    health.died.connect(_on_died)

    damage_area = Area2D.new()
    damage_area.collision_layer = 32
    damage_area.collision_mask = 2
    var damage_shape = CollisionShape2D.new()
    var area_shape = RectangleShape2D.new()
    area_shape.size = Vector2(22, 31)
    damage_shape.shape = area_shape
    damage_shape.position = Vector2(0, -3)
    damage_area.add_child(damage_shape)
    add_child(damage_area)
    damage_area.body_entered.connect(_on_damage_area_body_entered)

func _max_hp_for_difficulty():
    match GameState.difficulty:
        "easy": return 5
        "hard": return 7
        "nightmare": return 8
        _: return 6

func _physics_process(delta):
    if dead:
        return

    spit_timer = max(0.0, spit_timer - delta)
    recoil_left = max(0.0, recoil_left - delta)

    if not is_on_floor():
        velocity.y += GameRules.GRAVITY * delta

    var player = get_tree().get_first_node_in_group("players")
    var desired_x = _patrol_velocity()

    if windup_left > 0.0:
        windup_left = max(0.0, windup_left - delta)
        current_state = "windup"
        desired_x = 0.0
        sprite.modulate = Color(0.63, 1.0, 0.42, 1.0)
        if player != null and not player.dead:
            sprite.flip_h = player.global_position.x < global_position.x
        if windup_left <= 0.0:
            _fire_spit(player)
    else:
        sprite.modulate = Color.WHITE
        if player != null and not player.dead:
            var dx = player.global_position.x - global_position.x
            var distance_x = abs(dx)
            var target_dir = int(sign(dx))
            if target_dir == 0:
                target_dir = patrol_direction

            if distance_x <= ACTIVATION_RANGE:
                sprite.flip_h = target_dir < 0
                if distance_x < RETREAT_RANGE:
                    current_state = "retreat"
                    desired_x = -target_dir * speed
                elif distance_x >= SPIT_MIN_RANGE and distance_x <= SPIT_MAX_RANGE:
                    current_state = "stalk"
                    desired_x = target_dir * speed * 0.18
                    if spit_timer <= 0.0:
                        _start_windup()
                        desired_x = 0.0
                elif distance_x > SPIT_MAX_RANGE:
                    current_state = "approach"
                    desired_x = target_dir * speed * 0.78
                else:
                    current_state = "hold"
                    desired_x = 0.0
            else:
                current_state = "patrol"
        else:
            current_state = "patrol"

    var move_dir = int(sign(desired_x))
    if move_dir != 0 and is_on_floor() and not _has_floor_ahead(move_dir):
        if current_state == "patrol":
            patrol_direction *= -1
        desired_x = 0.0

    velocity.x = desired_x
    move_and_slide()

    if is_on_wall():
        patrol_direction *= -1

    if current_state == "patrol" and abs(global_position.x - spawn_x) > PATROL_RADIUS:
        patrol_direction = -1 if global_position.x > spawn_x else 1

    _update_visual_motion(delta)

    if global_position.y > 190.0:
        queue_free()
    if GameState.debug_collision_visible:
        queue_redraw()

func _start_windup():
    windup_left = 0.44
    spit_timer = spit_interval
    velocity.x = 0.0

func _fire_spit(player):
    if player == null or not is_instance_valid(player) or player.dead:
        return

    var dx = player.global_position.x - global_position.x
    var distance_x = abs(dx)
    var direction_x = -1.0 if dx < 0.0 else 1.0
    sprite.flip_h = direction_x < 0.0

    # A readable high arc rather than a hitscan shot: the player sees the launch,
    # can move under/away from it, and must account for the temporary puddle afterward.
    var horizontal_speed = clamp(distance_x * 0.78, 82.0, 132.0)
    var upward_speed = 96.0 + clamp((distance_x - 80.0) * 0.18, 0.0, 18.0)
    var difficulty = GameRules.difficulty_data(GameState.difficulty)
    horizontal_speed *= float(difficulty["enemy_projectile_speed_scale"])
    upward_speed *= sqrt(float(difficulty["enemy_projectile_speed_scale"]))

    var glob = AcidGlob.new()
    glob.setup(direction_x, horizontal_speed, upward_speed, 2)
    get_tree().current_scene.add_child(glob)
    glob.global_position = global_position + Vector2(direction_x * 18.0, -22.0)
    recoil_left = 0.16

func _update_visual_motion(delta):
    var moving = abs(velocity.x) > 1.0 and is_on_floor() and windup_left <= 0.0
    if moving:
        walk_phase += delta * 8.5
        var step = sin(walk_phase)
        sprite.position.y = SPRITE_REST_Y + step * 1.1
        sprite.rotation = step * 0.010
        sprite.flip_h = velocity.x < 0.0
    else:
        sprite.position.y = lerp(sprite.position.y, SPRITE_REST_Y, min(1.0, delta * 14.0))
        sprite.rotation = lerp(sprite.rotation, 0.0, min(1.0, delta * 12.0))

    if windup_left > 0.0:
        var pulse = 1.0 + sin(windup_left * 32.0) * 0.025
        sprite.scale = Vector2(0.30 * pulse, 0.30 / pulse)
        sprite.position.x = (-1.0 if sprite.flip_h else 1.0) * 1.0
    elif recoil_left > 0.0:
        sprite.scale = Vector2(0.306, 0.294)
        sprite.position.x = (2.0 if sprite.flip_h else -2.0)
    else:
        sprite.scale = sprite.scale.lerp(Vector2(0.30, 0.30), min(1.0, delta * 16.0))
        sprite.position.x = lerp(sprite.position.x, 0.0, min(1.0, delta * 16.0))

func _patrol_velocity():
    if patrol_direction == 0:
        patrol_direction = -1
    return patrol_direction * speed * 0.64

func _has_floor_ahead(direction: int):
    var space_state = get_world_2d().direct_space_state
    var from = global_position + Vector2(direction * 12.0, -1.0)
    var to = from + Vector2(0.0, 35.0)
    var query = PhysicsRayQueryParameters2D.create(from, to, 1)
    query.exclude = [get_rid()]
    return not space_state.intersect_ray(query).is_empty()

func take_damage(amount, source_position = Vector2.ZERO):
    if dead:
        return false
    if health.damage(amount):
        var knock = sign(global_position.x - source_position.x)
        if knock == 0.0:
            knock = -1.0 if sprite.flip_h else 1.0
        velocity.x = knock * 36.0
        sprite.modulate = Color(1.0, 1.0, 1.0, 0.52)
        var tween = create_tween()
        tween.tween_property(sprite, "modulate", Color.WHITE, 0.10)
        return true
    return false

func _on_damage_area_body_entered(body):
    if body.is_in_group("players") and body.has_method("take_damage"):
        body.take_damage(1, global_position)

func _on_died():
    if dead:
        return
    dead = true
    collision_layer = 0
    collision_mask = 0
    if damage_area != null:
        damage_area.set_deferred("monitoring", false)
        damage_area.set_deferred("monitorable", false)
    GameState.register_enemy_kill(175)
    defeated.emit(self)
    var tween = create_tween()
    tween.tween_property(sprite, "scale", Vector2(0.34, 0.22), 0.09)
    tween.tween_property(sprite, "modulate", Color(0.38, 1.0, 0.08, 0.0), 0.30)
    tween.finished.connect(queue_free)

func _draw():
    if GameState.debug_collision_visible:
        draw_rect(Rect2(Vector2(-10, -18), Vector2(20, 30)), Color(0.3, 1.0, 0.15, 0.55), false, 1.0)
