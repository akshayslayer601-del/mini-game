extends Node2D

# WARZONE: LAST STAND
# Godot 4.7.x / GDScript
# Self-contained top-down war shooter. No external assets or plugins required.
# The existing project structure, Godot version and Netlify setup are preserved.

const VIEW_SIZE: Vector2 = Vector2(960.0, 540.0)
const ARENA: Rect2 = Rect2(30.0, 85.0, 900.0, 425.0)
const MAX_WAVE: int = 8

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var screen: String = "title"
var wave: int = 0
var score: int = 0
var kills: int = 0
var high_score: int = 0
var player_pos: Vector2 = Vector2(480.0, 410.0)
var player_health: float = 100.0
var player_max_health: float = 100.0
var ammo: int = 30
var max_ammo: int = 30
var grenades: int = 3
var fire_cooldown: float = 0.0
var reload_time: float = 0.0
var invulnerable_time: float = 0.0
var wave_delay: float = 0.0
var game_time: float = 0.0
var mouse_pos: Vector2 = Vector2(480.0, 270.0)
var mouse_down: bool = false
var paused: bool = false
var wave_message_time: float = 0.0
var wave_message: String = ""

var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var enemy_bullets: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var obstacles: Array[Rect2] = []

func _ready() -> void:
    rng.randomize()
    high_score = 0
    setup_obstacles()
    queue_redraw()

func setup_obstacles() -> void:
    obstacles.clear()
    obstacles.append(Rect2(150.0, 145.0, 150.0, 38.0))
    obstacles.append(Rect2(390.0, 130.0, 180.0, 38.0))
    obstacles.append(Rect2(665.0, 155.0, 140.0, 38.0))
    obstacles.append(Rect2(105.0, 300.0, 42.0, 125.0))
    obstacles.append(Rect2(815.0, 300.0, 42.0, 125.0))
    obstacles.append(Rect2(350.0, 330.0, 115.0, 38.0))
    obstacles.append(Rect2(515.0, 330.0, 115.0, 38.0))
    obstacles.append(Rect2(390.0, 445.0, 180.0, 30.0))

func _process(delta: float) -> void:
    if screen == "game" and not paused:
        game_time += delta
        update_game(delta)
    elif screen == "title":
        game_time += delta
    elif screen == "result":
        game_time += delta

    if wave_message_time > 0.0:
        wave_message_time -= delta

    queue_redraw()

func _physics_process(delta: float) -> void:
    if screen != "game" or paused:
        return

    if fire_cooldown > 0.0:
        fire_cooldown -= delta
    if reload_time > 0.0:
        reload_time -= delta
        if reload_time <= 0.0:
            ammo = max_ammo
    if invulnerable_time > 0.0:
        invulnerable_time -= delta

    update_player(delta)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        mouse_pos = event.position
    elif event is InputEventMouseButton:
        var mouse_event: InputEventMouseButton = event
        if mouse_event.button_index == MOUSE_BUTTON_LEFT:
            mouse_down = mouse_event.pressed
            if mouse_event.pressed:
                handle_pointer(mouse_event.position)
        elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
            throw_grenade(mouse_event.position)
    elif event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event
        if touch.pressed:
            mouse_pos = touch.position
            handle_pointer(touch.position)
    elif event is InputEventScreenDrag:
        var drag: InputEventScreenDrag = event
        mouse_pos = drag.position
    elif event is InputEventKey:
        var key_event: InputEventKey = event
        if key_event.pressed and not key_event.echo:
            handle_key(key_event.keycode)

func handle_key(key: Key) -> void:
    if screen == "title":
        if key == KEY_ENTER or key == KEY_SPACE:
            start_game()
        return

    if screen == "result":
        if key == KEY_ENTER or key == KEY_SPACE or key == KEY_R:
            start_game()
        return

    if screen != "game":
        return

    if key == KEY_ESCAPE or key == KEY_P:
        paused = not paused
    elif key == KEY_R:
        start_reload()
    elif key == KEY_G:
        throw_grenade(mouse_pos)

func handle_pointer(pos: Vector2) -> void:
    mouse_pos = pos

    if screen == "title":
        if Rect2(330.0, 380.0, 300.0, 72.0).has_point(pos):
            start_game()
        return

    if screen == "result":
        if Rect2(330.0, 380.0, 300.0, 72.0).has_point(pos):
            start_game()
        return

    if screen != "game":
        return

    if paused:
        if Rect2(350.0, 330.0, 260.0, 64.0).has_point(pos):
            paused = false
        return

    # Touch/mobile shooting: tap in the arena shoots toward the tap.
    if pos.y > 80.0:
        shoot(pos)

func start_game() -> void:
    screen = "game"
    paused = false
    wave = 0
    score = 0
    kills = 0
    player_health = player_max_health
    ammo = max_ammo
    grenades = 3
    player_pos = Vector2(480.0, 410.0)
    fire_cooldown = 0.0
    reload_time = 0.0
    invulnerable_time = 0.0
    wave_delay = 0.0
    enemies.clear()
    bullets.clear()
    enemy_bullets.clear()
    particles.clear()
    pickups.clear()
    start_next_wave()

func start_next_wave() -> void:
    wave += 1
    if wave > MAX_WAVE:
        win_game()
        return

    enemies.clear()
    wave_delay = 0.0
    wave_message = "WAVE %d  —  INCOMING!" % wave
    wave_message_time = 1.8

    var count: int = 4 + wave * 2
    for i in range(count):
        spawn_enemy(i)

    if wave == MAX_WAVE:
        spawn_boss()

func spawn_enemy(index: int) -> void:
    var side: int = rng.randi_range(0, 3)
    var pos: Vector2 = Vector2.ZERO
    if side == 0:
        pos = Vector2(rng.randf_range(65.0, 895.0), 105.0)
    elif side == 1:
        pos = Vector2(895.0, rng.randf_range(105.0, 490.0))
    elif side == 2:
        pos = Vector2(rng.randf_range(65.0, 895.0), 490.0)
    else:
        pos = Vector2(65.0, rng.randf_range(105.0, 490.0))

    var enemy_type: int = 0
    if wave >= 3 and index % 4 == 0:
        enemy_type = 1
    if wave >= 5 and index % 6 == 0:
        enemy_type = 2

    var hp: float = 35.0 + float(wave) * 7.0
    var speed: float = 52.0 + float(wave) * 4.0
    var radius: float = 15.0
    if enemy_type == 1:
        hp = 65.0 + float(wave) * 9.0
        speed = 40.0 + float(wave) * 2.0
        radius = 19.0
    elif enemy_type == 2:
        hp = 28.0 + float(wave) * 5.0
        speed = 86.0 + float(wave) * 5.0
        radius = 13.0

    enemies.append({
        "pos": pos,
        "hp": hp,
        "max_hp": hp,
        "speed": speed,
        "radius": radius,
        "type": enemy_type,
        "shoot_timer": rng.randf_range(0.6, 1.8),
        "hit_flash": 0.0
    })

func spawn_boss() -> void:
    enemies.append({
        "pos": Vector2(480.0, 115.0),
        "hp": 550.0,
        "max_hp": 550.0,
        "speed": 28.0,
        "radius": 31.0,
        "type": 3,
        "shoot_timer": 0.8,
        "hit_flash": 0.0
    })

func update_game(delta: float) -> void:
    update_enemies(delta)
    update_bullets(delta)
    update_enemy_bullets(delta)
    update_particles(delta)
    update_pickups(delta)

    if enemies.is_empty():
        if wave_delay <= 0.0:
            wave_delay = 1.4
        else:
            wave_delay -= delta
            if wave_delay <= 0.0:
                start_next_wave()

    if player_health <= 0.0:
        lose_game()

func update_player(delta: float) -> void:
    var direction: Vector2 = Vector2.ZERO
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        direction.y -= 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        direction.y += 1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        direction.x -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        direction.x += 1.0

    if direction.length_squared() > 0.0:
        direction = direction.normalized()
        var next_pos: Vector2 = player_pos + direction * 230.0 * delta
        player_pos = move_with_obstacles(player_pos, next_pos, 18.0)

    player_pos.x = clampf(player_pos.x, ARENA.position.x + 22.0, ARENA.end.x - 22.0)
    player_pos.y = clampf(player_pos.y, ARENA.position.y + 22.0, ARENA.end.y - 22.0)

    if mouse_down and mouse_pos.y > 80.0:
        shoot(mouse_pos)

func move_with_obstacles(current: Vector2, desired: Vector2, radius: float) -> Vector2:
    var result: Vector2 = desired
    for rect in obstacles:
        var expanded: Rect2 = rect.grow(radius)
        if expanded.has_point(result):
            var left_dist: float = absf(result.x - expanded.position.x)
            var right_dist: float = absf(result.x - expanded.end.x)
            var top_dist: float = absf(result.y - expanded.position.y)
            var bottom_dist: float = absf(result.y - expanded.end.y)
            var smallest: float = minf(minf(left_dist, right_dist), minf(top_dist, bottom_dist))
            if smallest == left_dist:
                result.x = expanded.position.x
            elif smallest == right_dist:
                result.x = expanded.end.x
            elif smallest == top_dist:
                result.y = expanded.position.y
            else:
                result.y = expanded.end.y
    return result

func shoot(target_pos: Vector2) -> void:
    if screen != "game" or paused:
        return
    if reload_time > 0.0:
        return
    if ammo <= 0:
        start_reload()
        return
    if fire_cooldown > 0.0:
        return

    var direction: Vector2 = player_pos.direction_to(target_pos)
    if direction.length_squared() <= 0.01:
        return

    ammo -= 1
    fire_cooldown = 0.105
    bullets.append({
        "pos": player_pos + direction * 27.0,
        "vel": direction * 720.0,
        "life": 0.85,
        "damage": 28.0
    })
    add_muzzle_particles(player_pos + direction * 30.0, direction)

    if ammo <= 0:
        start_reload()

func start_reload() -> void:
    if screen != "game":
        return
    if ammo >= max_ammo or reload_time > 0.0:
        return
    reload_time = 1.0

func throw_grenade(target_pos: Vector2) -> void:
    if screen != "game" or paused or grenades <= 0:
        return
    var direction: Vector2 = player_pos.direction_to(target_pos)
    if direction.length_squared() <= 0.01:
        return

    grenades -= 1
    var grenade_pos: Vector2 = player_pos + direction * 28.0
    # Grenade is represented as a fast projectile with a timed fuse.
    bullets.append({
        "pos": grenade_pos,
        "vel": direction * 330.0,
        "life": 0.62,
        "damage": 130.0,
        "grenade": true
    })

func update_bullets(delta: float) -> void:
    var remove_indices: Array[int] = []

    for i in range(bullets.size()):
        var bullet: Dictionary = bullets[i]
        var pos: Vector2 = bullet["pos"]
        var vel: Vector2 = bullet["vel"]
        pos += vel * delta
        bullet["pos"] = pos
        bullet["life"] = float(bullet["life"]) - delta
        bullets[i] = bullet

        var grenade: bool = bool(bullet.get("grenade", false))
        var dead: bool = float(bullet["life"]) <= 0.0

        if grenade:
            if dead:
                grenade_explosion(pos, float(bullet["damage"]))
                remove_indices.append(i)
            continue

        if dead or not ARENA.grow(-2.0).has_point(pos):
            remove_indices.append(i)
            continue

        var hit_obstacle: bool = false
        for rect in obstacles:
            if rect.grow(2.0).has_point(pos):
                hit_obstacle = true
                break
        if hit_obstacle:
            spawn_particles(pos, 5, Color("#d0d0d0"), 55.0)
            remove_indices.append(i)
            continue

        var hit_enemy: bool = false
        for e in range(enemies.size() - 1, -1, -1):
            var enemy: Dictionary = enemies[e]
            var enemy_pos: Vector2 = enemy["pos"]
            var enemy_radius: float = enemy["radius"]
            if pos.distance_to(enemy_pos) <= enemy_radius + 5.0:
                enemy["hp"] = float(enemy["hp"]) - float(bullet["damage"])
                enemy["hit_flash"] = 0.10
                enemies[e] = enemy
                spawn_particles(pos, 7, Color("#ffd166"), 90.0)
                hit_enemy = true
                if float(enemy["hp"]) <= 0.0:
                    kill_enemy(e)
                break

        if hit_enemy:
            remove_indices.append(i)

    remove_indices.reverse()
    for index in remove_indices:
        if index >= 0 and index < bullets.size():
            bullets.remove_at(index)

func kill_enemy(index: int) -> void:
    if index < 0 or index >= enemies.size():
        return
    var enemy: Dictionary = enemies[index]
    var pos: Vector2 = enemy["pos"]
    var enemy_type: int = int(enemy["type"])

    if enemy_type == 3:
        score += 2500
        spawn_particles(pos, 55, Color("#ff7b54"), 210.0)
        grenade_explosion(pos, 180.0)
    else:
        score += 100 + wave * 25
        spawn_particles(pos, 20, Color("#ff5d5d"), 145.0)

    kills += 1
    if rng.randf() < 0.14:
        pickups.append({"pos": pos, "type": 0, "life": 8.0})
    elif rng.randf() < 0.07:
        pickups.append({"pos": pos, "type": 1, "life": 8.0})

    enemies.remove_at(index)

func grenade_explosion(center: Vector2, damage: float) -> void:
    spawn_particles(center, 48, Color("#ff8c42"), 240.0)
    for i in range(enemies.size() - 1, -1, -1):
        var enemy: Dictionary = enemies[i]
        var dist: float = center.distance_to(enemy["pos"])
        if dist < 115.0:
            var scaled_damage: float = damage * (1.0 - dist / 150.0)
            enemy["hp"] = float(enemy["hp"]) - scaled_damage
            enemy["hit_flash"] = 0.18
            enemies[i] = enemy
            if float(enemy["hp"]) <= 0.0:
                kill_enemy(i)

func update_enemies(delta: float) -> void:
    for i in range(enemies.size()):
        var enemy: Dictionary = enemies[i]
        var pos: Vector2 = enemy["pos"]
        var enemy_type: int = int(enemy["type"])
        var speed: float = float(enemy["speed"])
        var to_player: Vector2 = pos.direction_to(player_pos)
        var dist: float = pos.distance_to(player_pos)

        if enemy_type == 3:
            # Boss circles the arena and fires heavy bursts.
            var tangent: Vector2 = Vector2(-to_player.y, to_player.x)
            var movement: Vector2 = (to_player * 0.18 + tangent * 0.82).normalized()
            var next_boss: Vector2 = pos + movement * speed * delta
            enemy["pos"] = keep_enemy_in_arena(next_boss, 35.0)
        elif dist > 72.0:
            var next_pos: Vector2 = pos + to_player * speed * delta
            enemy["pos"] = keep_enemy_in_arena(next_pos, float(enemy["radius"]))
        else:
            if invulnerable_time <= 0.0:
                var melee_damage: float = 8.0 if enemy_type == 2 else 5.0
                if enemy_type == 3:
                    melee_damage = 14.0
                player_health -= melee_damage * delta

        var shoot_timer: float = float(enemy["shoot_timer"]) - delta
        if shoot_timer <= 0.0 and dist < 520.0:
            var interval: float = 1.65 - minf(float(wave) * 0.07, 0.8)
            if enemy_type == 1:
                interval = 1.25
            elif enemy_type == 2:
                interval = 2.1
            elif enemy_type == 3:
                interval = 0.55

            enemy_bullets.append({
                "pos": pos + to_player * (float(enemy["radius"]) + 5.0),
                "vel": to_player * (260.0 + float(wave) * 9.0 + (80.0 if enemy_type == 3 else 0.0)),
                "damage": 9.0 if enemy_type < 3 else 16.0,
                "life": 3.0,
                "radius": 5.0 if enemy_type < 3 else 8.0
            })
            shoot_timer = interval

        enemy["shoot_timer"] = shoot_timer
        if float(enemy["hit_flash"]) > 0.0:
            enemy["hit_flash"] = float(enemy["hit_flash"]) - delta
        enemies[i] = enemy

func keep_enemy_in_arena(pos: Vector2, radius: float) -> Vector2:
    var result: Vector2 = pos
    result.x = clampf(result.x, ARENA.position.x + radius, ARENA.end.x - radius)
    result.y = clampf(result.y, ARENA.position.y + radius, ARENA.end.y - radius)
    return result

func update_enemy_bullets(delta: float) -> void:
    var remove_indices: Array[int] = []
    for i in range(enemy_bullets.size()):
        var bullet: Dictionary = enemy_bullets[i]
        var pos: Vector2 = bullet["pos"]
        pos += Vector2(bullet["vel"]) * delta
        bullet["pos"] = pos
        bullet["life"] = float(bullet["life"]) - delta
        enemy_bullets[i] = bullet

        if float(bullet["life"]) <= 0.0 or not ARENA.grow(-5.0).has_point(pos):
            remove_indices.append(i)
            continue

        var blocked: bool = false
        for rect in obstacles:
            if rect.grow(2.0).has_point(pos):
                blocked = true
                break
        if blocked:
            spawn_particles(pos, 4, Color("#b8c0d0"), 45.0)
            remove_indices.append(i)
            continue

        if pos.distance_to(player_pos) < 20.0 and invulnerable_time <= 0.0:
            player_health -= float(bullet["damage"])
            invulnerable_time = 0.28
            spawn_particles(player_pos, 14, Color("#ff3b30"), 110.0)
            remove_indices.append(i)

    remove_indices.reverse()
    for index in remove_indices:
        if index >= 0 and index < enemy_bullets.size():
            enemy_bullets.remove_at(index)

func update_pickups(delta: float) -> void:
    var remove_indices: Array[int] = []
    for i in range(pickups.size()):
        var item: Dictionary = pickups[i]
        item["life"] = float(item["life"]) - delta
        pickups[i] = item

        if player_pos.distance_to(item["pos"]) < 30.0:
            var pickup_type: int = int(item["type"])
            if pickup_type == 0:
                ammo = max_ammo
                score += 50
            else:
                player_health = minf(player_max_health, player_health + 35.0)
                score += 75
            spawn_particles(player_pos, 16, Color("#72f1b8"), 120.0)
            remove_indices.append(i)
        elif float(item["life"]) <= 0.0:
            remove_indices.append(i)

    remove_indices.reverse()
    for index in remove_indices:
        if index >= 0 and index < pickups.size():
            pickups.remove_at(index)

func add_muzzle_particles(pos: Vector2, direction: Vector2) -> void:
    spawn_particles(pos + direction * 5.0, 6, Color("#ffe08a"), 110.0)

func spawn_particles(pos: Vector2, count: int, color: Color, speed: float) -> void:
    for i in range(count):
        var angle: float = rng.randf_range(0.0, TAU)
        var particle_speed: float = rng.randf_range(speed * 0.35, speed)
        particles.append({
            "pos": pos,
            "vel": Vector2.RIGHT.rotated(angle) * particle_speed,
            "life": rng.randf_range(0.22, 0.62),
            "max_life": 0.62,
            "color": color,
            "size": rng.randf_range(1.5, 4.5)
        })

func update_particles(delta: float) -> void:
    var remove_indices: Array[int] = []
    for i in range(particles.size()):
        var p: Dictionary = particles[i]
        p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * delta
        p["vel"] = Vector2(p["vel"]) * 0.90
        p["life"] = float(p["life"]) - delta
        particles[i] = p
        if float(p["life"]) <= 0.0:
            remove_indices.append(i)

    remove_indices.reverse()
    for index in remove_indices:
        if index >= 0 and index < particles.size():
            particles.remove_at(index)

func win_game() -> void:
    screen = "result"
    high_score = max(high_score, score)
    paused = false
    wave_message_time = 0.0
    spawn_particles(Vector2(480.0, 300.0), 90, Color("#ffd166"), 260.0)

func lose_game() -> void:
    screen = "result"
    high_score = max(high_score, score)
    paused = false
    spawn_particles(player_pos, 60, Color("#ff4d5d"), 220.0)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#080c14"), true)

    if screen == "title":
        draw_title()
    elif screen == "game":
        draw_battlefield()
        draw_hud()
        if paused:
            draw_pause()
    elif screen == "result":
        draw_result()

func draw_title() -> void:
    # Animated war-room background.
    for i in range(14):
        var x: float = float(i) * 74.0
        var y: float = 105.0 + sin(game_time * 0.45 + float(i)) * 18.0
        draw_circle(Vector2(x, y), 2.0, Color("#35435c"))

    draw_centered_text("WARZONE", 125.0, 62, Color("#f4f7ff"))
    draw_centered_text("LAST STAND", 177.0, 34, Color("#ff5d5d"))
    draw_centered_text("ONE SOLDIER  •  EIGHT WAVES  •  HOLD THE LINE", 218.0, 18, Color("#9aa8c5"))

    draw_card(Rect2(205.0, 250.0, 550.0, 92.0))
    draw_centered_text("WASD / ARROWS  MOVE", 282.0, 20, Color("#e9edf7"))
    draw_centered_text("MOUSE  AIM + FIRE     R  RELOAD     G / RIGHT CLICK  GRENADE", 316.0, 16, Color("#9aa8c5"))

    draw_button(Rect2(330.0, 380.0, 300.0, 72.0), "DEPLOY", Color("#b52d3b"))
    draw_centered_text("Press ENTER or SPACE", 485.0, 16, Color("#6f7e9c"))

func draw_battlefield() -> void:
    # Ground grid.
    draw_rect(ARENA, Color("#101923"), true)
    draw_rect(ARENA, Color("#39485e"), false, 3.0)

    var grid_x: float = ARENA.position.x
    while grid_x < ARENA.end.x:
        draw_line(Vector2(grid_x, ARENA.position.y), Vector2(grid_x, ARENA.end.y), Color("#172432"), 1.0)
        grid_x += 45.0

    var grid_y: float = ARENA.position.y
    while grid_y < ARENA.end.y:
        draw_line(Vector2(ARENA.position.x, grid_y), Vector2(ARENA.end.x, grid_y), Color("#172432"), 1.0)
        grid_y += 45.0

    # Battlefield markings.
    draw_circle(Vector2(480.0, 300.0), 78.0, Color("#111e2c"))
    draw_circle(Vector2(480.0, 300.0), 78.0, Color("#26364a"), false, 2.0)
    draw_line(Vector2(450.0, 300.0), Vector2(510.0, 300.0), Color("#2f4158"), 2.0)
    draw_line(Vector2(480.0, 270.0), Vector2(480.0, 330.0), Color("#2f4158"), 2.0)

    for rect in obstacles:
        draw_rect(rect, Color("#263342"), true)
        draw_rect(rect, Color("#4b5b6e"), false, 2.0)
        var stripe_x: float = rect.position.x + 8.0
        while stripe_x < rect.end.x:
            draw_line(Vector2(stripe_x, rect.position.y), Vector2(stripe_x - 18.0, rect.end.y), Color("#334456"), 2.0)
            stripe_x += 24.0

    for pickup in pickups:
        var ppos: Vector2 = pickup["pos"]
        var ptype: int = int(pickup["type"])
        var pc: Color = Color("#72f1b8") if ptype == 0 else Color("#63b3ff")
        draw_circle(ppos, 13.0 + sin(game_time * 5.0) * 2.0, Color(pc, 0.18))
        draw_rect(Rect2(ppos - Vector2(9.0, 9.0), Vector2(18.0, 18.0)), pc, true)
        if ptype == 0:
            draw_string(ThemeDB.fallback_font, ppos + Vector2(-5.0, 6.0), "A", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("#071019"))
        else:
            draw_string(ThemeDB.fallback_font, ppos + Vector2(-5.0, 6.0), "+", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("#071019"))

    for bullet in bullets:
        var bpos: Vector2 = bullet["pos"]
        var grenade: bool = bool(bullet.get("grenade", false))
        var bc: Color = Color("#ff9f43") if grenade else Color("#fff1a8")
        var radius: float = 6.0 if grenade else 3.0
        draw_circle(bpos, radius, bc)

    for bullet in enemy_bullets:
        var ebpos: Vector2 = bullet["pos"]
        draw_circle(ebpos, float(bullet["radius"]), Color("#ff4d5d"))

    for enemy in enemies:
        draw_enemy(enemy)

    draw_player()

    for p in particles:
        var life_ratio: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
        var particle_color: Color = p["color"]
        particle_color.a = life_ratio
        draw_circle(p["pos"], float(p["size"]) * life_ratio, particle_color)

func draw_player() -> void:
    var aim: Vector2 = player_pos.direction_to(mouse_pos)
    if aim.length_squared() <= 0.01:
        aim = Vector2.RIGHT

    var flash: bool = invulnerable_time > 0.0 and int(game_time * 18.0) % 2 == 0
    var body_color: Color = Color("#ffffff") if flash else Color("#4aa3df")

    draw_circle(player_pos, 24.0, Color("#05080d"))
    draw_circle(player_pos, 20.0, body_color)

    # Helmet.
    draw_circle(player_pos + Vector2(0.0, -5.0), 13.0, Color("#6e8c63"))
    draw_arc(player_pos + Vector2(0.0, -5.0), 13.0, PI, TAU, 20, Color("#9cb58c"), 3.0)

    # Gun.
    draw_line(player_pos + aim * 8.0, player_pos + aim * 36.0, Color("#11151b"), 9.0)
    draw_line(player_pos + aim * 10.0, player_pos + aim * 36.0, Color("#56616f"), 5.0)

    # Direction indicator.
    draw_circle(player_pos + aim * 17.0, 3.5, Color("#ffdb6e"))

func draw_enemy(enemy: Dictionary) -> void:
    var pos: Vector2 = enemy["pos"]
    var radius: float = float(enemy["radius"])
    var enemy_type: int = int(enemy["type"])
    var hp: float = float(enemy["hp"])
    var max_hp: float = float(enemy["max_hp"])
    var hit_flash: bool = float(enemy["hit_flash"]) > 0.0

    var body_color: Color = Color("#ffffff") if hit_flash else Color("#b73545")
    if enemy_type == 1:
        body_color = Color("#ffffff") if hit_flash else Color("#6e5a42")
    elif enemy_type == 2:
        body_color = Color("#ffffff") if hit_flash else Color("#8b3d6b")
    elif enemy_type == 3:
        body_color = Color("#ffffff") if hit_flash else Color("#9b2226")

    draw_circle(pos, radius + 4.0, Color("#05070b"))
    draw_circle(pos, radius, body_color)

    if enemy_type == 3:
        draw_arc(pos, radius + 8.0, 0.0, TAU, 28, Color("#ff9f43"), 3.0)
        draw_line(pos + Vector2(-radius, 0.0), pos + Vector2(radius, 0.0), Color("#ff9f43"), 4.0)
    else:
        draw_circle(pos + Vector2(0.0, -4.0), radius * 0.52, Color("#30363f"))
        draw_line(pos + Vector2(-radius * 0.55, 8.0), pos + Vector2(radius * 0.55, 8.0), Color("#1d2229"), 3.0)

    if enemy_type == 2:
        draw_line(pos + Vector2(0.0, -radius), pos + Vector2(0.0, -radius - 10.0), Color("#e1b12c"), 3.0)

    var bar_width: float = radius * 2.5
    draw_rect(Rect2(pos.x - bar_width / 2.0, pos.y - radius - 11.0, bar_width, 4.0), Color("#25141a"), true)
    draw_rect(Rect2(pos.x - bar_width / 2.0, pos.y - radius - 11.0, bar_width * clampf(hp / max_hp, 0.0, 1.0), 4.0), Color("#65d46e"), true)

func draw_hud() -> void:
    draw_rect(Rect2(0.0, 0.0, VIEW_SIZE.x, 76.0), Color("#090e17"), true)
    draw_line(Vector2(0.0, 76.0), Vector2(960.0, 76.0), Color("#34445b"), 2.0)

    draw_string(ThemeDB.fallback_font, Vector2(28.0, 29.0), "WARZONE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color("#ff6875"))
    draw_string(ThemeDB.fallback_font, Vector2(28.0, 53.0), "WAVE %d / %d" % [wave, MAX_WAVE], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color("#dbe4f3"))

    draw_string(ThemeDB.fallback_font, Vector2(220.0, 29.0), "SCORE %06d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color("#f1f4fa"))
    draw_string(ThemeDB.fallback_font, Vector2(220.0, 53.0), "KILLS %03d" % kills, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color("#9eacc0"))

    draw_string(ThemeDB.fallback_font, Vector2(440.0, 29.0), "HEALTH", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color("#9eacc0"))
    draw_rect(Rect2(440.0, 39.0, 190.0, 14.0), Color("#25151b"), true)
    draw_rect(Rect2(440.0, 39.0, 190.0 * clampf(player_health / player_max_health, 0.0, 1.0), 14.0), Color("#e74c5b"), true)

    draw_string(ThemeDB.fallback_font, Vector2(675.0, 29.0), "AMMO", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color("#9eacc0"))
    var ammo_text: String = "RELOADING..." if reload_time > 0.0 else "%02d / %02d" % [ammo, max_ammo]
    draw_string(ThemeDB.fallback_font, Vector2(675.0, 54.0), ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 19, Color("#f2d06b"))

    draw_string(ThemeDB.fallback_font, Vector2(815.0, 29.0), "GRENADES", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color("#9eacc0"))
    draw_string(ThemeDB.fallback_font, Vector2(815.0, 54.0), "%d" % grenades, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 19, Color("#72d49a"))

    if wave_message_time > 0.0:
        var alpha: float = clampf(wave_message_time / 1.8, 0.0, 1.0)
        var msg_color: Color = Color(1.0, 0.82, 0.35, alpha)
        draw_centered_text(wave_message, 112.0, 26, msg_color)

func draw_pause() -> void:
    draw_rect(Rect2(0.0, 0.0, VIEW_SIZE.x, VIEW_SIZE.y), Color(0.02, 0.03, 0.05, 0.78), true)
    draw_centered_text("PAUSED", 210.0, 54, Color("#ffffff"))
    draw_centered_text("The battlefield is waiting.", 250.0, 19, Color("#aebbd0"))
    draw_button(Rect2(350.0, 330.0, 260.0, 64.0), "RESUME", Color("#4d78b8"))
    draw_centered_text("Press P or ESC", 425.0, 16, Color("#75839a"))

func draw_result() -> void:
    var won: bool = wave > MAX_WAVE
    var title: String = "MISSION COMPLETE" if won else "YOU WERE OVERRUN"
    var main_color: Color = Color("#65d46e") if won else Color("#ff5968")

    draw_centered_text(title, 135.0, 48, main_color)
    draw_centered_text("WARZONE: LAST STAND", 178.0, 20, Color("#aebbd0"))

    draw_card(Rect2(250.0, 225.0, 460.0, 120.0))
    draw_centered_text("FINAL SCORE  %06d" % score, 267.0, 27, Color("#ffffff"))
    draw_centered_text("ENEMIES ELIMINATED  %03d" % kills, 305.0, 19, Color("#b9c5d7"))
    draw_centered_text("BEST SCORE  %06d" % high_score, 333.0, 16, Color("#7e8ca3"))

    draw_button(Rect2(330.0, 380.0, 300.0, 72.0), "DEPLOY AGAIN", main_color)
    draw_centered_text("Press ENTER, SPACE, or R", 485.0, 16, Color("#75839a"))

func draw_card(rect: Rect2) -> void:
    draw_rect(rect, Color("#121a27"), true)
    draw_rect(rect, Color("#34445b"), false, 2.0)

func draw_button(rect: Rect2, label: String, fill: Color) -> void:
    draw_rect(rect, Color("#060a10"), true)
    draw_rect(rect, fill, true)
    draw_rect(rect, Color(1.0, 1.0, 1.0, 0.16), false, 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.62), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 22, Color("#ffffff"))

func draw_centered_text(text: String, y: float, size: int, color: Color, left: float = 0.0, right: float = 960.0) -> void:
    draw_string(ThemeDB.fallback_font, Vector2(left, y), text, HORIZONTAL_ALIGNMENT_CENTER, right - left, size, color)
