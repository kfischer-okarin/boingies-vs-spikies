require "app/base.rb"
require "app/camera.rb"
require "app/camera_movement.rb"
require "app/damage_numbers.rb"
require "app/launcher.rb"
require "app/pathfinding.rb"
require "app/turret.rb"
require "app/essence.rb"
require "app/stage_editor.rb"

def tick(args)
  setup(args) if args.tick_count.zero?

  case args.state.scene
  when :game
    game_tick(args)
  when :stage_editor
    StageEditor.tick(args)
  end
end

# TODO: should we move these game_* to a Game class/module?
def game_tick(args)
  game_process_inputs(args)
  game_update(args)
  game_render(args)
end

def setup(args)
  args.state.show_debug_info = false
  args.state.scene = :game
  args.state.stage = load_stage
  args.state.navigation_grid = Pathfinding.build_navigation_grid(args.state.stage, spacing: 30, grid_type: Pathfinding::HexGrid)
  args.state.enemies = []
  args.state.base = Base.build args.state.stage
  args.state.camera = Camera.build center_x: args.state.base[:x], center_y: args.state.base[:y]
  args.state.launcher = Launcher.build
  args.state.launched_turrets = []
  args.state.stationary_turrets = []
  args.state.projectiles = []

  args.state.dmg_popups = []
  args.state.essence_drops = []
  args.state.essence_held = 300
  args.state.enemy_unique_id = 0
  args.state.current_turret_type = 1
  DamageNumbers.setup(args)
end

def load_stage
  $gtk.deserialize_state("stage")
end

def game_process_inputs(args)
  unless game_over?(args)
    CameraMovement.control_camera(
      mouse: args.inputs.mouse,
      camera: args.state.camera,
      stage: args.state.stage
    )
    Launcher.control_launcher(args)
    change_selected_turret(args)
    unless $gtk.production?
      StageEditor.handle_onoff(args)
      handle_toggle_debug_info(args)
    end
  end
  $gtk.reset if args.inputs.keyboard.key_up.r
end

def change_selected_turret(args)
  k = args.inputs.keyboard

  if k.key_down.one
    args.state.current_turret_type -=1
    args.state.current_turret_type = 0 if args.state.current_turret_type < 0
  end
  #this should be more dynamic with the actual options avaliable, currently only got 2 functioning
  #see build turret for what these mean
  if k.key_down.two
    args.state.current_turret_type +=1
    args.state.current_turret_type = 1 if args.state.current_turret_type > 1
  end
end

def build_turret(args)
  p = args.state.base
  launcher = args.state.launcher
  type = Turret::TYPES[args.state.current_turret_type].name
  #puts angle = Math.atan2(launcher.direction.y- (p.y+p.h/2), launcher.direction.x - (p.x+p.w/2))
  #CD should be based on turret type
  {
    x: p.x, y: p.y,
    w: 20, h: 20,
    dx: launcher[:direction].x, dy: launcher[:direction].y,
    logical_x: p.x, logical_y: p.y,
    pow: launcher[:power] / 5,
    type: Turret::TYPES[args.state.current_turret_type].name,
    cost: Turret::TYPES[args.state.current_turret_type].cost,
    cd: 60,
    angle: launcher[:angle]
  }
end

def handle_toggle_debug_info(args)
  return unless args.inputs.keyboard.key_down.nine

  args.state.show_debug_info = !args.state.show_debug_info
end

def game_update(args)
  return if game_over?(args)

  spawn_spikey(args) if args.inputs.keyboard.key_held.five || args.tick_count.mod_zero?(60)
  move_enemies(args)
  handle_enemy_vs_base_collisions(args)
  handle_dead_enemies(args)
  Launcher.update(args)
  update_launched_turrets(args)
  tick_turret(args)
  DamageNumbers.update_all(args.state.dmg_popups)
  update_essence(args)
end

def spawn_spikey(args)
  spawn_zone = args.state.stage.spawn_zones.sample

  args.state.enemies << {
    x: spawn_zone.x + rand(spawn_zone.w).to_i,
    y: spawn_zone.y + rand(spawn_zone.h).to_i,
    w: 100, h: 100,
    anchor_x: 0.5, anchor_y: 0.5,
    health: 100,
    type: :spikey_ball,
    essence_amount: 10,
    unique_id: args.state.enemy_unique_id
  }

  args.state.enemy_unique_id += 1
end

def move_enemies(args)
  args.state.enemies.each do |enemy|
    move_enemy(args, enemy)
  end
end

def move_enemy(args, enemy)
  to_base = Pathfinding.direction_to_base(args.state.navigation_grid, enemy)
  speed = 2
  enemy[:x] += to_base[:x] * speed
  enemy[:y] += to_base[:y] * speed
end

def handle_dead_enemies(args)
  args.state.enemies.reject! { |enemy| enemy_dead?(args, enemy) }
end

def enemy_dead?(args, enemy)
  enemy.health <= 0
end

def handle_enemy_vs_base_collisions(args)
  args.state.enemies.each do |enemy|
    if enemy.intersect_rect? args.state.base
      args.state.base.health -= 5
      enemy.health = 0
    end
  end
end

def update_launched_turrets args
  args.state.launched_turrets.reject!{|lau| lau.pow <=0}

  butt = collidable_stage_bounds(args)

  args.state.launched_turrets.each do |lau|
    #yes this insantiy is just to ensure I can calc the wibble seperately XD
    x_vel, y_vel = vel_from_angle(lau.angle, 1)
    lau.x += x_vel * lau.pow
    lau.y += (y_vel + Math.sin(args.tick_count)) * lau.pow
    x_vel, y_vel = vel_from_angle(lau.angle, lau.pow)
    #lau.x += lau.dx * lau.pow
    #lau.y += (lau.dy + Math.sin(args.tick_count*2)) * lau.pow

    lau.logical_x += x_vel #lau.dx * lau.pow
    lau.logical_y += y_vel #lau.dy * lau.pow

    args.state.stage.walls.each do |wall|
      if lau.intersect_rect? wall
        lau.logical_x, lau.logical_y = bounce(lau, wall)
        lau.x, lau.y = lau.logical_x, lau.logical_y
      end
    end
    butt = collidable_stage_bounds(args)
    #stage = args.state.stage
    butt.each do |wall|
      if lau.intersect_rect? wall
        lau.logical_x, lau.logical_y = bounce(lau, wall)
        lau.x, lau.y = lau.logical_x, lau.logical_y
      end
    end

    lau.pow -= 1
    if lau.pow <= 0
      lau.pow = 0
      #eh symbols for turrets?
      potential_turret = makeTurret(lau.logical_x, lau.logical_y, lau.cd, lau.type)
      fusion = false
      args.state.stationary_turrets.each do |turret|
        if potential_turret.type == turret.type && circle_col(potential_turret, turret) && fusion == false
          fusion = true
          fuse_turret(turret, potential_turret)
          break;
        end
      end
      if fusion == false
        args.state.stationary_turrets << potential_turret
      end
    end
  end
end

def collidable_stage_bounds(args)
  bounds = stage_bounds(args.state.stage)
  pad = 100

  left_collider  = { x: bounds.left - pad, y: bounds.bottom - pad, w: pad,              h: bounds.h + pad*2}
  right_collider = { x: bounds.right,      y: bounds.bottom - pad, w: pad,              h: bounds.h + pad*2}
  up_collider    = { x: bounds.left - pad, y: bounds.top,          w: bounds.w + pad*2, h: pad}
  down_collider  = { x: bounds.left - pad, y: bounds.bottom - pad, w: bounds.w + pad*2, h: pad}

  args.state.ahhhhh = [left_collider, right_collider, up_collider, down_collider]
end

def stage_bounds(stage)
  { x: -stage[:w] / 2, y: -stage[:h] / 2, w: stage[:w], h: stage[:h] }
end

def game_over?(args)
  Base.dead?(args.state.base) # || winning condition
end

def game_render(args)
  render_base(args)
  render_stage(args)
  render_enemies(args)
  render_turrets(args)
  render_launcher_ui(args) if args.state.launcher[:state] == :charging
  render_game_over(args) if Base.dead?(args.state.base)
  render_debug_info(args) if args.state.show_debug_info
  DamageNumbers.render_all(args, args.state.dmg_popups)
  render_essence(args)

  render_turret_debug(args) if args.state.show_debug_info
  render_stage_bounds_colliders(args) if args.state.show_debug_info
end

def render_base(args)
  camera = args.state.camera
  base = args.state.base
  args.outputs.primitives << [
    Camera.transform!(camera, Base.sprite(base)),
    Camera.transform!(camera, Base.health_label(base)),
  ]

end

def render_stage(args)
  stage = args.state.stage
  camera = args.state.camera
  args.outputs.primitives << stage[:walls].map { |wall|
    Camera.transform! camera, wall.to_sprite(path: :pixel, r: 255, g: 0, b: 0)
  }
  render_spawn_zones(args)
  render_stage_border(args)
end

def render_spawn_zones(args)
  zones = args.state.stage.spawn_zones
  camera = args.state.camera

  args.outputs.primitives << zones.map do |zone|
    Camera.transform! camera, zone.to_sprite(path: :pixel, r: 255, g: 0, b: 0, a: 50)
  end
end

def render_stage_border(args)
  stage = args.state.stage
  camera = args.state.camera
  bounds_on_screen = Camera.transform! camera, stage_bounds(stage)
  border_style = { path: :pixel, r: 100, g: 100, b: 100 }
  args.outputs.primitives << [
    { x: 0, y: 0, w: bounds_on_screen.left, h: 720 }.sprite!(border_style),
    { x: 0, y: 0, w: 1280, h: bounds_on_screen.bottom }.sprite!(border_style),
    { x: bounds_on_screen.right, y: 0, w: 1280 - bounds_on_screen.right, h: 720 }.sprite!(border_style),
    { x: 0, y: bounds_on_screen.top, w: 1280, h: 720 - bounds_on_screen.top }.sprite!(border_style)
  ]
end

def render_stage_bounds_colliders(args)
  camera = args.state.camera
  args.outputs.primitives << collidable_stage_bounds(args).map { |turret|
    Camera.transform! camera, turret.to_sprite(path: :pixel, r: 0, g: 200, b: 0)
  }
end


def render_enemies(args)
  camera = args.state.camera
  args.outputs.primitives << args.state.enemies.map { |enemy|
    Camera.transform! camera, enemy.to_sprite(
      path: "sprites/#{enemy[:type]}.png"
    )
  }
end

def render_turrets(args)
  camera = args.state.camera
  args.outputs.primitives << args.state.launched_turrets.map { |turret|
    Camera.transform! camera, turret.to_sprite(path: :pixel, r: 0, g: 0, b: 0)
  }

  args.outputs.primitives << args.state.stationary_turrets.map { |turret|
    Camera.transform! camera, turret.to_sprite(path: :pixel, r: 0, g: 0, b: 200)
  }

  args.outputs.primitives << args.state.projectiles.map { |shot|
    Camera.transform! camera, shot.to_sprite(path: :pixel)
  }
end

def render_turret_debug(args)
  camera = args.state.camera
  args.outputs.primitives << args.state.stationary_turrets.map { |turret|
    Camera.transform! camera, setup_circle(turret, turret.range)
  }

  args.outputs.primitives << args.state.stationary_turrets.map { |turret|
    Camera.transform! camera, setup_circle(turret, turret.fusion_range).merge(r:200, g: 0)
  }
end

def render_launcher_ui(args)
  launcher = args.state.launcher

  args.outputs.primitives << Launcher.charge_bar_sprite(launcher)

  if Launcher.charging?(launcher)
    sprite = Launcher.direction_marker_sprite(args)
    args.outputs.primitives << sprite if sprite
  end
end

def render_game_over(args)
  args.outputs.primitives << [
    {
      x: 0, y: 0,
      w: 1280, h: 720,
      r: 255, g: 255, b: 255,
      a: 180 + Math.sin(args.state.tick_count / 100) * 75,
      path: :pixel
    }.to_sprite,
    {
      text: "GAME OVER",
      x: args.grid.w / 2, y: 360,
      size_px: 200,
      alignment_enum: 1,
      vertical_alignment_enum: 1,
      r: 0, g: 0, b: 0
    }.to_label,
    {
      text: "press R to restart",
      x: args.grid.w / 2, y: 250,
      size_px: 50,
      alignment_enum: 1,
      vertical_alignment_enum: 1,
      r: 0, g: 0, b: 0
    }.to_label
  ]
end

def render_debug_info(args)
  mouse = mouse_in_world(args)

  args.outputs.primitives << [
    { x: 0, y: 660, w: 200, h: 60, r: 0, g: 0, b: 0, a: 128, path: :pixel }.sprite!,
    { x: 5, y: 715, text: "FPS: #{args.gtk.current_framerate.to_i}", r: 255, g: 255, b: 255 }.label!,
    { x: 5, y: 690, text: "Mouse: (#{mouse.x.round(2)}, #{mouse.y.round(2)})", r: 255, g: 255, b: 255 }.label!
  ]
end

def mouse_in_world(args)
  mouse_point = { x: args.inputs.mouse.x, y: args.inputs.mouse.y, w: 0, h: 0 }
  Camera.to_world_coordinates!(args.state.camera, mouse_point)
end

def fat_border(rect, line_width:, **values)
  [
    { x: rect.x - line_width, y: rect.y - line_width, w: rect.w + line_width * 2, h: line_width, path: :pixel }.sprite!(values),
    { x: rect.x - line_width, y: rect.y - line_width, w: line_width, h: rect.h + line_width * 2, path: :pixel }.sprite!(values),
    { x: rect.x - line_width, y: rect.y + rect.h, w: rect.w + line_width * 2, h: line_width, path: :pixel }.sprite!(values),
    { x: rect.x + rect.w, y: rect.y - line_width, w: line_width, h: rect.h + line_width * 2, path: :pixel }.sprite!(values)
  ]
end

def angle_from_vector(vector)
  Math.atan2(vector.y, vector.x).to_degrees
end

def vel_from_angle(angle, speed)
  [speed * Math.cos(angle.to_radians), speed * Math.sin(angle.to_radians)]
end

def direction_between(from, to)
  result = Matrix.vec2(to.x - from.x, to.y - from.y)
  Matrix.normalize! result
  result
end

def distance_between(obj1, obj2)
  distance = Math.sqrt( ((obj1.x - obj2.x)**2) + ((obj1.y - obj2.y)**2) )
end

def bounce(bullet, other)
  vx,vy = vel_from_angle(bullet.angle, bullet.pow)
  bx = bullet.logical_x - vx
  by = bullet.logical_y - vy

  #vertial wall hit
  bullet.angle = 0 - bullet.angle if  by + bullet.h <= other.y ||
  by >= other.y+ other.h
  #horizontal wall hit
  bullet.angle = 180 - bullet.angle if bx + bullet.w <= other.x ||
  bx >= other.x+ other.w
  [bx,by]
end

$gtk.reset
