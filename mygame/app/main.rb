require 'app/camera.rb'
require 'app/stage.rb'

def tick(args)
  setup(args) if args.tick_count.zero?

  process_inputs(args)
  update(args)
  render(args)
end

def setup(args)
  args.state.walls = stage_walls
  args.state.enemies = []
  args.state.camera = Camera.build
  args.state.player_area = { x: -100, y: -100, w: 200, h: 200 }
end

def process_inputs(args)
  mouse = args.inputs.mouse
  camera = args.state.camera
  mouse_camera_movement(mouse, camera)
  mouse_camera_zoom(mouse, camera)
end

def mouse_camera_movement(mouse, camera)
  return unless mouse.has_focus

  camera_move_area = 50
  camera_move_speed = 10 / camera[:zoom]
  if mouse.x <= camera_move_area
    camera[:center_x] -= camera_move_speed
  elsif mouse.x >= 1280 - camera_move_area
    camera[:center_x] += camera_move_speed
  end

  if mouse.y <= camera_move_area
    camera[:center_y] -= camera_move_speed
  elsif mouse.y >= 720 - camera_move_area
    camera[:center_y] += camera_move_speed
  end
end

def mouse_camera_zoom(mouse, camera)
  return unless mouse.wheel

  camera[:zoom] += mouse.wheel.y * 0.1 * camera[:zoom]
  camera[:zoom] = camera[:zoom].clamp(0.25, 4)
end

def update(args)
  spawn_spikey(args) if args.tick_count.mod_zero? 60
  move_enemies(args)
  handle_dead_enemies(args)
end

def spawn_spikey(args)
  direction = %i[top right bottom left].sample
  case direction
  when :top
    x = -1200 + rand(1200)
    y = 1200
  when :right
    x = 1200
    y = -1200 + rand(1200)
  when :bottom
    x = -1200 + rand(1200)
    y = -1200
  when :left
    x = -1200
    y = -1200 + rand(1200)
  end

  args.state.enemies << {
    x: x, y: y, w: 100, h: 100,
    anchor_x: 0.5, anchor_y: 0.5,
    type: :spikey_ball
  }
end

def move_enemies(args)
  args.state.enemies.each do |enemy|
    distance_to_center = Math.sqrt(enemy[:x]**2 + enemy[:y]**2)
    speed = 2
    enemy[:x] += -(enemy[:x] / distance_to_center) * speed
    enemy[:y] += -(enemy[:y] / distance_to_center) * speed
  end
end

def handle_dead_enemies(args)
  args.state.enemies.reject! { |enemy| enemy_dead?(args, enemy) }
end

def enemy_dead?(args, enemy)
  # for now die when enemy touches player area
  enemy.intersect_rect? args.state.player_area
end

def render(args)
  render_player_area(args)
  render_walls(args)
  render_enemies(args)
end

def render_player_area(args)
  camera = args.state.camera
  args.outputs.primitives << Camera.transform!(
    camera,
    args.state.player_area.to_sprite(path: :pixel, r: 0, g: 200, b: 0)
  )
end

def render_walls(args)
  camera = args.state.camera
  args.outputs.primitives << args.state.walls.map { |wall|
    Camera.transform! camera, wall.to_sprite(path: :pixel, r: 0, g: 0, b: 0)
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

$gtk.reset
