require "app/base.rb"
require "app/camera.rb"
require "app/camera_movement.rb"
require "app/damage_numbers.rb"
require "app/launcher.rb"
require "app/pathfinding.rb"
require "app/collisions.rb"
require "app/turret.rb"
require "app/essence.rb"
require "app/enemies.rb"
require "app/stage_editor.rb"
require "app/waves.rb"

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
  make_wallRts(args)
  args.state.navigation_grid = Pathfinding.build_navigation_grid(args.state.stage, spacing: 30, grid_type: Pathfinding::HexGrid)
  args.state.enemies = []
  args.state.base = Base.build args.state.stage
  args.state.camera = Camera.build center_x: args.state.base[:x], center_y: args.state.base[:y]
  args.state.launcher = Launcher.build
  args.state.launched_turrets = []
  args.state.stationary_turrets = []
  args.state.projectiles = []
  args.state.waves_state = Waves.build_state args.state.stage

  args.state.dmg_popups = []
  args.state.essence_drops = []
  args.state.essence_held = 300
  args.state.enemy_unique_id = 0
  args.state.current_turret_type = 1
  args.state.selected_turret_type = Turret.available_turret_types(args).first
  DamageNumbers.setup(args)

  foilageSprites = ["flowers.png", "flowers1.png", "rocks.png", "rocks1.png"]
  args.state.foilage =[]
  nFoilage = 50
  bounds = stage_bounds(args.state.stage)
  foliage_w = 200
  foliage_h = 200
  nFoilage.times do |i|
    x = bounds.left + rand(bounds.w - foliage_w)
    y = bounds.bottom + rand(bounds.h - foliage_h)
    foily = foilageSprites[rand(foilageSprites.length)]
    args.state.foilage << { x: x, y: y, w: foliage_w, h: foliage_h, path: "sprites/#{foily}" }
  end

  args.audio[:bgm] = { input: 'audio/bgm.ogg', looping: true }
end

def load_stage
  $gtk.deserialize_state("stage")
end

def game_process_inputs(args)
  unless game_over?(args)
    CameraMovement.control_camera(
      inputs: args.inputs,
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
  input_chars = args.inputs.text

  Turret.available_turret_types(args).each_with_index do |turret_type, index|
    hotkey = (index + 1).to_s
    args.state.selected_turret_type = turret_type if input_chars == [hotkey]
  end
end

def handle_toggle_debug_info(args)
  return unless args.inputs.keyboard.key_down.nine

  args.state.show_debug_info = !args.state.show_debug_info
end

def game_update(args)
  return if game_over?(args)

  Waves.tick(args, args.state.waves_state)
  Enemies.update(args)
  Enemies.handle_enemy_vs_base_collisions(args)
  Enemies.handle_dead_ones(args)
  handle_next_wave(args) if Waves.in_wave?(args.state.waves_state)
  Launcher.update(args)
  update_launched_turrets(args)
  tick_turret(args)
  DamageNumbers.update_all(args.state.dmg_popups)
  update_essence(args)
end

def handle_next_wave(args)
  waves_state = args.state.waves_state
  return unless Waves.no_more_enemies_in_this_wave?(waves_state) && args.state.enemies.empty?

  if Waves.last_wave?(waves_state)
    # Show win / go to next stage screen?
  else
    Waves.prepare_next_wave(waves_state)
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

    lau.pow -= 0.1
    if lau.pow <= 0
      lau.pow = 0
      potential_turret = Turret.build(lau.type, x: lau.logical_x, y: lau.logical_y)
      fusion = false
      args.state.stationary_turrets.each do |turret|
        next unless potential_turret.type == turret.type && circle_col(potential_turret, turret)

        fusion = true
        fuse_turret(turret, potential_turret)
        break
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
  render_debug_info(args) if args.state.show_debug_info
  DamageNumbers.render_all(args, args.state.dmg_popups)
  render_essence(args)
  render_turret_selection_ui(args)
  render_wave_info(args)

  if args.state.show_debug_info
    render_turret_debug(args)
    render_stage_bounds_colliders(args)
  end

  render_game_over(args) if Base.dead?(args.state.base)
end

def render_base(args)
  camera = args.state.camera
  base = args.state.base
  args.outputs.primitives << Camera.transform!(camera, Base.sprite(base))
  Base.health_bar_sprites(base).each do |sprite|
    args.outputs.primitives << Camera.transform!(camera, sprite)
  end
end

def render_stage(args)
  args.outputs.background_color = [155,173,183]
  stage = args.state.stage
  camera = args.state.camera
  args.outputs.primitives << args.state.foilage.map { |foili|
    Camera.transform! camera, foili.to_sprite( r: 255, g: 255, b: 255)
  }
  args.outputs.primitives << stage[:walls].map { |wall|
    Camera.transform! camera, wall.to_sprite( r: 255, g: 255, b: 255)
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

def render_enemies(args)
  camera = args.state.camera
  args.outputs.primitives << args.state.enemies.map { |enemy|
    Camera.transform! camera, enemy.to_sprite
  }
end

def render_turrets(args)
  camera = args.state.camera
  args.outputs.primitives << args.state.launched_turrets.map { |turret|
    Camera.transform! camera, turret.to_sprite(path: "sprites/slimeBall.png", r: 200, g: 200, b: 200)
  }

  args.outputs.primitives << args.state.stationary_turrets.map { |turret|
    Camera.transform! camera, turret.to_sprite(r: 255, g: 255, b: 255)
  }

  args.outputs.primitives << args.state.projectiles.map { |shot|
    Camera.transform! camera, shot.to_sprite(a:255)
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

def render_turret_selection_ui(args)
  Turret.available_turret_types(args).each_with_index do |turret_type, i|
    turret_definition = Turret.definition(turret_type)
    rect = { x: 200 + i * 80, y: 20, w: 64, h: 64 }
    args.outputs.primitives << rect.to_sprite(path: :pixel, r: 255, g: 255, b: 255, a: 200)
    args.outputs.primitives << rect.to_sprite(path: "sprites/turret_#{turret_type}.png")
    args.outputs.primitives << { x: rect.left, y: rect.top, text: (i + 1).to_s }.label!
    args.outputs.primitives << {
      x: rect.right - 5, y: rect.bottom + 20,
      text: turret_definition[:cost].to_s, r: 200, g: 0, b: 0,
      alignment_enum: 2
    }.label!
    if args.state.selected_turret_type == turret_type
      args.outputs.primitives << fat_border(rect, line_width: 5, r: 255, g: 150, b: 0)
    end
  end
end

def render_wave_info(args)
  waves_state = args.state.waves_state
  args.outputs.primitives << {
    x: 640, y: 30, size_px: 30, text: "Wave #{waves_state[:wave_index] + 1}",
    alignment_enum: 1
  }.label!
  return if Waves.in_wave? waves_state

  args.outputs.primitives << {
    x: 640, y: 700, size_px: 40, text: 'Next wave in',
    alignment_enum: 1
  }.label!
  args.outputs.primitives << {
    x: 640, y: 660, size_px: 60, text: (waves_state[:timer] / 60).ceil.to_s,
    alignment_enum: 1
  }.label!
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

def render_turret_debug(args)
  camera = args.state.camera
  args.outputs.primitives << args.state.stationary_turrets.map { |turret|
    Camera.transform! camera, setup_circle(turret, turret.range)
  }

  args.outputs.primitives << args.state.stationary_turrets.map { |turret|
    Camera.transform! camera, setup_circle(turret, turret.fusion_range).merge(r:200, g: 0)
  }

  sight_lines = args.state.stationary_turrets.flat_map do |turret|
    enemies_in_range = Turret.enemies_in_range(turret, args.state.enemies)
    enemies_in_range.map do |enemy|
      visible = Turret.can_see_enemy?(turret, enemy, args.state.stage)
      color = { r: visible ? 255 : 0, g: 0, b: 0 }
      line = Turret.line_of_sight(turret, enemy)
      Camera.transform(camera, line).merge(color).line
    end
  end
  args.outputs.primitives << sight_lines if sight_lines.size > 0
end

def render_stage_bounds_colliders(args)
  camera = args.state.camera
  args.outputs.primitives << collidable_stage_bounds(args).map { |turret|
    Camera.transform! camera, turret.to_sprite(path: :pixel, r: 0, g: 200, b: 0)
  }
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
  Math.sqrt( ((obj1.x - obj2.x)**2) + ((obj1.y - obj2.y)**2) )
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


def make_wallRts(args)
  stage = args.state.stage
  stage[:walls].map_with_index do |wall, i|
    make_9_slice(11,11, "sprites/slimeWall2.png", wall.w, wall.h, args, true, "wall#{i}")
    wall[:path] = "wall#{i}"
  end
end


def make_9_slice(tile_w,tile_h, sprite_name, box_width, box_height, args, fill, symbol)
	mid_w = box_width-(tile_w*2)
	mid_h = box_height-(tile_h*2)
	args.outputs[symbol]
	slice=args.outputs[symbol].sprites
	args.outputs[symbol].w = box_width
	args.outputs[symbol].h = box_height
	#setup source positions for edge sprites
	s_r_x = tile_w*2
	r_y = tile_h*2
	#set final locations for right and top edges
	r_x = box_width-tile_w
	t_y = box_height-tile_h

	bl_corner = {x:0,y:0,w:tile_w,h:tile_h, path:sprite_name, source_x:0, source_y:0, source_w:tile_w,source_h:tile_h}
	br_corner = {x:r_x,y:0,w:tile_w,h:tile_h, path:sprite_name, source_x:s_r_x, source_y:0, source_w:tile_w,source_h:tile_h}
	tl_corner = {x:0,y:t_y,w:tile_w,h:tile_h, path:sprite_name, source_x:0, source_y:r_y, source_w:tile_w,source_h:tile_h}
	tr_corner = {x:r_x,y:t_y,w:tile_w,h:tile_h, path:sprite_name, source_x:s_r_x, source_y:r_y, source_w:tile_w,source_h:tile_h}

	#left and right mid pieces
	n_h = (mid_h/tile_h.to_f).ceil
	#top and bottom mid pieces
	n_w = (mid_w/tile_w.to_f).ceil
	#to fill or not fill the center
  if(fill)
		n_h.times do |y|
			n_w.times do |x|

				if((y>-1 && y<n_h) && (x>-1 && x<n_w))
					mb = {x:(x+1)*tile_w,y:(y+1)*tile_h,w:tile_w,h:tile_h, path:sprite_name, source_x:tile_w, source_y:tile_h, source_w:tile_w,source_h:tile_h}
					slice << mb
				end
			end
		end
	end

	#place left and right mid pieces
	n_h.times do |i|
		ml = {x:0,y:(i+1)*tile_h,w:tile_w,h:tile_h, path:sprite_name, source_x:0, source_y:tile_h, source_w:tile_w,source_h:tile_h}
		slice << ml
		mr = {x:r_x,y:(i+1)*tile_h,w:tile_w,h:tile_h, path:sprite_name, source_x:s_r_x, source_y:tile_h, source_w:tile_w,source_h:tile_h}
		slice << mr
	end
	#place top and bottom mid pieces
	n_w.times do |i|
		mb = {x:(i+1)*tile_w,y:0,w:tile_w,h:tile_h, path:sprite_name, source_x:tile_w, source_y:0, source_w:tile_w,source_h:tile_h}
		slice << mb
		mt = {x:(i+1)*tile_w,y:t_y,w:tile_w,h:tile_h, path:sprite_name, source_x:tile_w, source_y:r_y, source_w:tile_w,source_h:tile_h}
		slice << mt
	end

	#added last so cover overspill of any partial centre pieces
	slice << bl_corner
	slice << br_corner
	slice << tl_corner
	slice << tr_corner
end

$gtk.reset
