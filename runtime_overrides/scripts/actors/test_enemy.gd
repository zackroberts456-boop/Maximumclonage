extends CharacterBody2D

signal defeated(enemy)

const HealthComponent = preload("res://scripts/components/health_component.gd")
const GameRules = preload("res://scripts/data/game_rules.gd")
const Projectile = preload("res://scripts/weapons/projectile.gd")

const PATROL_RADIUS = 82.0
const ACTIVATION_RANGE = 220.0
const SHOOT_MIN_RANGE = 66.0
const SHOOT_MAX_RANGE = 142.0
const RETREAT_RANGE = 42.0
const SPRITE_REST_Y = -31.0

var spawn_x = 0.0
var patrol_direction = -1
var speed = 33.0
var fire_interval = 0.92
var projectile_speed = 122.0
var shoot_timer = 0.28
var dead = false
var health
var sprite
var damage_area
var current_state = "patrol"
var walk_phase = 0.0
var recoil_left = 0.0
var elite = false
var base_sprite_scale = 0.30

func make_elite():
    elite = true

func _ready():
    add_to_group("enemies")
    collision_layer = 4
    collision_mask = 1
    spawn_x = global_position.x

    var difficulty = GameRules.difficulty_data(GameState.difficulty)
    speed *= float(difficulty["enemy_speed_scale"])
    fire_interval *= float(difficulty["enemy_fire_interval_scale"])
    projectile_speed *= float(difficulty["enemy_projectile_speed_scale"])

    if elite:
        speed *= 1.12
        fire_interval *= 0.72
        projectile_speed *= 1.08
        base_sprite_scale = 0.33

    var collider = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(18, 30)
    collider.shape = shape
    collider.position = Vector2(0, -3)
    add_child(collider)

    # High-detail production grunt artwork. Gameplay collision stays identical to the
    # stable build; only the visual layer changes, so platforming/enemy balance does not.
    sprite = Sprite2D.new()
    sprite.texture = load("res://assets/enemies/clone_grunt_production.png")
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.scale = Vector2(base_sprite_scale, base_sprite_scale)
    sprite.position = Vector2(0, SPRITE_REST_Y)
    if elite:
        sprite.modulate = Color(1.0, 0.83, 0.58, 1.0)
    add_child(sprite)

    health = HealthComponent.new()
    health.configure(9 if elite else 4, 0.10)
    add_child(health)
    health.died.connect(_on_died)

    damage_area = Area2D.new()
    damage_area.collision_layer = 32
    damage_area.collision_mask = 2
    var damage_shape = CollisionShape2D.new()
    var area_shape = RectangleShape2D.new()
    area_shape.size = Vector2(20, 31)
    damage_shape.shape = area_shape
    damage_shape.position = Vector2(0, -3)
    damage_area.add_child(damage_shape)
    add_child(damage_area)
    damage_area.body_entered.connect(_on_damage_area_body_entered)

func _physics_process(delta):
    if dead:
        return

    shoot_timer = max(0.0, shoot_timer - delta)
    recoil_left = max(0.0, recoil_left - delta)

    if not is_on_floor():
        velocity.y += GameRules.GRAVITY * delta

    var player = get_tree().get_first_node_in_group("players")
    var desired_x = _patrol_velocity()

    if player != null and not player.dead:
        var dx = player.global_position.x - global_position.x
        var distance_x = abs(dx)
        if distance_x <= ACTIVATION_RANGE:
            var target_dir = int(sign(dx))
            if target_dir == 0:
                target_dir = patrol_direction

            if distance_x < RETREAT_RANGE:
                current_state = "retreat"
                desired_x = -target_dir * speed * 0.92
            elif distance_x < SHOOT_MIN_RANGE:
                current_state = "hold"
                desired_x = 0.0
                _try_shoot(player)
            elif distance_x <= SHOOT_MAX_RANGE:
                current_state = "strafe"
                desired_x = target_dir * speed * 0.38
                _try_shoot(player)
            else:
                current_state = "chase"
                desired_x = target_dir * speed

            if desired_x == 0.0:
                sprite.flip_h = target_dir < 0
        else:
            current_state = "patrol"
            desired_x = _patrol_velocity()
    else:
        current_state = "patrol"
        desired_x = _patrol_velocity()

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

func _update_visual_motion(delta):
    var moving = abs(velocity.x) > 1.0 and is_on_floor()
    if moving:
        walk_phase += delta * (12.0 + abs(velocity.x) * 0.035)
        var step = sin(walk_phase)
        sprite.position.y = SPRITE_REST_Y + step * 1.25
        sprite.rotation = step * 0.012
        var squash = step * 0.006
        sprite.scale = Vector2(base_sprite_scale + squash, base_sprite_scale - squash)
        sprite.flip_h = velocity.x < 0.0
    else:
        sprite.position.y = lerp(sprite.position.y, SPRITE_REST_Y, min(1.0, delta * 14.0))
        sprite.rotation = lerp(sprite.rotation, 0.0, min(1.0, delta * 14.0))
        sprite.scale = sprite.scale.lerp(Vector2(base_sprite_scale, base_sprite_scale), min(1.0, delta * 14.0))

    if recoil_left > 0.0:
        var recoil_dir = 1.0 if sprite.flip_h else -1.0
        sprite.position.x = recoil_dir * 1.5
    else:
        sprite.position.x = lerp(sprite.position.x, 0.0, min(1.0, delta * 18.0))

func _patrol_velocity():
    if patrol_direction == 0:
        patrol_direction = -1
    return patrol_direction * speed * 0.76

func _has_floor_ahead(direction: int):
    var space_state = get_world_2d().direct_space_state
    var from = global_position + Vector2(direction * 12.0, -1.0)
    var to = from + Vector2(0.0, 35.0)
    var query = PhysicsRayQueryParameters2D.create(from, to, 1)
    query.exclude = [get_rid()]
    return not space_state.intersect_ray(query).is_empty()

func _try_shoot(player):
    if shoot_timer > 0.0:
        return
    shoot_timer = fire_interval
    recoil_left = 0.09
    var direction = (player.global_position + Vector2(0, -9) - (global_position + Vector2(0, -10))).normalized()
    sprite.flip_h = direction.x < 0.0
    var projectile = Projectile.new()
    projectile.setup(direction, projectile_speed, 2 if elite else 1, "enemy")
    get_tree().current_scene.add_child(projectile)
    projectile.global_position = global_position + Vector2(sign(direction.x) * 20.0, -10)

func take_damage(amount, source_position = Vector2.ZERO):
    if dead:
        return false
    if health.damage(amount):
        var knock = sign(global_position.x - source_position.x)
        if knock == 0.0:
            knock = -1.0 if sprite.flip_h else 1.0
        velocity.x = knock * 42.0
        sprite.modulate = Color(1.0, 1.0, 1.0, 0.50)
        var tween = create_tween()
        var restore = Color(1.0, 0.83, 0.58, 1.0) if elite else Color.WHITE
        tween.tween_property(sprite, "modulate", restore, 0.10)
        return true
    return false

func _on_damage_area_body_entered(body):
    if body.is_in_group("players") and body.has_method("take_damage"):
        body.take_damage(2 if elite else 1, global_position)

func _on_died():
    if dead:
        return
    dead = true
    collision_layer = 0
    collision_mask = 0
    if damage_area != null:
        damage_area.set_deferred("monitoring", false)
        damage_area.set_deferred("monitorable", false)
    GameState.register_enemy_kill(350 if elite else 100)
    defeated.emit(self)
    var tween = create_tween()
    tween.tween_property(sprite, "modulate", Color(0.35, 1.0, 0.35, 0.0), 0.30)
    tween.finished.connect(queue_free)

func _draw():
    if GameState.debug_collision_visible:
        draw_rect(Rect2(Vector2(-9, -18), Vector2(18, 30)), Color(1.0, 0.2, 0.2, 0.55), false, 1.0)
