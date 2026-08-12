extends Area2D

const LIFE_TIME = 3.1
const DAMAGE_INTERVAL = 0.55

var life_left = LIFE_TIME
var damage_left = 0.12
var touching_players = []
var visual

func _ready():
    collision_layer = 32
    collision_mask = 2
    monitoring = true
    monitorable = true

    var collider = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(34, 7)
    collider.shape = shape
    collider.position = Vector2(0, -2)
    add_child(collider)

    visual = Polygon2D.new()
    visual.polygon = PackedVector2Array([
        Vector2(-18, 0), Vector2(-15, -3), Vector2(-10, -4), Vector2(-6, -7),
        Vector2(-2, -4), Vector2(3, -6), Vector2(7, -3), Vector2(12, -5),
        Vector2(17, -2), Vector2(18, 1), Vector2(-18, 1)
    ])
    visual.color = Color(0.34, 1.0, 0.07, 0.64)
    visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(visual)

    var rim = Line2D.new()
    rim.points = PackedVector2Array([
        Vector2(-16, -2), Vector2(-10, -3), Vector2(-6, -6), Vector2(-2, -3),
        Vector2(3, -5), Vector2(7, -2), Vector2(12, -4), Vector2(16, -1)
    ])
    rim.width = 1.0
    rim.default_color = Color(0.72, 1.0, 0.28, 0.90)
    add_child(rim)

    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func _process(delta):
    life_left -= delta
    damage_left -= delta

    if damage_left <= 0.0:
        damage_left = DAMAGE_INTERVAL
        _damage_touching_players()

    if visual != null:
        var pulse = 0.82 + sin((LIFE_TIME - life_left) * 9.0) * 0.10
        visual.scale.y = pulse
        if life_left < 0.7:
            visual.modulate.a = clamp(life_left / 0.7, 0.0, 1.0)

    if life_left <= 0.0:
        queue_free()

func _damage_touching_players():
    for index in range(touching_players.size() - 1, -1, -1):
        var body = touching_players[index]
        if body == null or not is_instance_valid(body):
            touching_players.remove_at(index)
            continue
        if body.is_in_group("players") and body.has_method("take_damage"):
            body.take_damage(1, global_position)

func _on_body_entered(body):
    if body.is_in_group("players"):
        if not touching_players.has(body):
            touching_players.append(body)
        if body.has_method("take_damage"):
            body.take_damage(1, global_position)
        damage_left = DAMAGE_INTERVAL

func _on_body_exited(body):
    touching_players.erase(body)
