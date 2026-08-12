extends Area2D

var center_x = 0.0
var top_y = 0.0
var bottom_y = 0.0
var top_exit_dir = 1

func setup(x_value: float, top_surface_y: float, bottom_surface_y: float, exit_direction: int = 1):
    center_x = x_value
    top_y = min(top_surface_y, bottom_surface_y)
    bottom_y = max(top_surface_y, bottom_surface_y)
    top_exit_dir = -1 if exit_direction < 0 else 1
    global_position = Vector2(center_x, (top_y + bottom_y) * 0.5)

func _ready():
    add_to_group("ladders")
    collision_layer = 64
    collision_mask = 2
    monitoring = true
    monitorable = true

    var height = max(20.0, bottom_y - top_y + 28.0)
    var collider = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = Vector2(20.0, height)
    collider.shape = shape
    collider.position = Vector2(0, 0)
    add_child(collider)

    _build_visual()
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func can_mount(player_position: Vector2, vertical_input: float):
    if abs(vertical_input) < 0.2:
        return false
    if abs(player_position.x - center_x) > 15.0:
        return false
    return player_position.y >= top_y - 24.0 and player_position.y <= bottom_y + 4.0

func get_top_standing_position():
    return Vector2(center_x + float(top_exit_dir) * 16.0, top_y - 18.0)

func get_bottom_standing_position():
    return Vector2(center_x, bottom_y - 18.0)

func should_exit_top(player_y: float, vertical_input: float):
    return vertical_input < -0.15 and player_y <= top_y + 5.0

func should_exit_bottom(player_y: float, vertical_input: float):
    return vertical_input > 0.15 and player_y >= bottom_y - 16.0

func _build_visual():
    var local_top = top_y - global_position.y - 6.0
    var local_bottom = bottom_y - global_position.y + 2.0

    for rail_x in [-6.0, 6.0]:
        var shadow = Line2D.new()
        shadow.points = PackedVector2Array([
            Vector2(rail_x + 1.0, local_top),
            Vector2(rail_x + 1.0, local_bottom)
        ])
        shadow.width = 3.0
        shadow.default_color = Color(0.015, 0.025, 0.03, 0.94)
        shadow.z_index = -1
        add_child(shadow)

        var rail = Line2D.new()
        rail.points = PackedVector2Array([
            Vector2(rail_x, local_top),
            Vector2(rail_x, local_bottom)
        ])
        rail.width = 2.0
        rail.default_color = Color(0.25, 0.34, 0.37, 1.0)
        add_child(rail)

        var highlight = Line2D.new()
        highlight.points = PackedVector2Array([
            Vector2(rail_x - 0.5, local_top),
            Vector2(rail_x - 0.5, local_bottom)
        ])
        highlight.width = 1.0
        highlight.default_color = Color(0.40, 0.54, 0.55, 0.82)
        add_child(highlight)

    var rung_y = ceil(local_top / 8.0) * 8.0
    while rung_y <= local_bottom:
        var rung_shadow = Line2D.new()
        rung_shadow.points = PackedVector2Array([
            Vector2(-6.0, rung_y + 1.0),
            Vector2(6.0, rung_y + 1.0)
        ])
        rung_shadow.width = 3.0
        rung_shadow.default_color = Color(0.01, 0.02, 0.025, 0.95)
        rung_shadow.z_index = -1
        add_child(rung_shadow)

        var rung = Line2D.new()
        rung.points = PackedVector2Array([
            Vector2(-6.0, rung_y),
            Vector2(6.0, rung_y)
        ])
        rung.width = 2.0
        rung.default_color = Color(0.27, 0.39, 0.40, 1.0)
        add_child(rung)
        rung_y += 8.0

    for marker_y in [local_top + 2.0, local_bottom - 2.0]:
        var marker = Line2D.new()
        marker.points = PackedVector2Array([
            Vector2(-9.0, marker_y),
            Vector2(9.0, marker_y)
        ])
        marker.width = 1.0
        marker.default_color = Color(0.38, 1.0, 0.23, 0.62)
        add_child(marker)

func _on_body_entered(body):
    if body.has_method("register_ladder"):
        body.register_ladder(self)

func _on_body_exited(body):
    if body.has_method("unregister_ladder"):
        body.unregister_ladder(self)
