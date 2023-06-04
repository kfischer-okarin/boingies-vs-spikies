module StageEditor
  class << self
    def start(args)
      args.state.stage_editor = {
        mode: :walls,
        selected: nil,
        selected_type: nil,
        dragged: nil
    }
    end

    def tick(args)
      process_inputs(args)
      render(args)
    end

    def handle_onoff(args)
      return unless args.inputs.keyboard.key_down.zero

      case args.state.scene
      when :game
        args.state.scene = :stage_editor
        start(args)
      when :stage_editor
        args.state.scene = :game
        args.state.navigation_grid = Pathfinding.build_navigation_grid(args.state.stage)
      end
    end

    private

    def process_inputs(args)
      CameraMovement.control_camera(
        mouse: args.inputs.mouse,
        camera: args.state.camera,
        stage: args.state.stage
      )
      handle_onoff(args)
      handle_change_mode(args)
      case args.state.stage_editor[:mode]
      when :walls
        handle_selection(args)
        if args.state.stage_editor[:selected]
          handle_delete(args)
          handle_rotate(args)
          handle_size_change(args)
          handle_drag(args)
        else
          handle_new_wall(args)
          handle_new_spawn_zone(args)
        end
        handle_save(args)
      end
    end

    def handle_selection(args)
      mouse = args.inputs.mouse
      return unless mouse.click

      clicked_position = mouse_in_world(args)
      clicked_wall = args.state.stage[:walls].find { |wall|
        clicked_position.inside_rect?(wall)
      }
      if clicked_wall
        select_object args, :wall, clicked_wall
        return
      end

      clicked_spawn_zone = args.state.stage[:spawn_zones].find { |zone|
        clicked_position.inside_rect?(zone)
      }
      if clicked_spawn_zone
        select_object args, :spawn_zone, clicked_spawn_zone
        return
      end

      deselect_object args
    end

    def select_object(args, type, object)
      args.state.stage_editor[:selected] = object
      args.state.stage_editor[:selected_type] = type
    end

    def deselect_object(args)
      args.state.stage_editor[:selected] = nil
      args.state.stage_editor[:selected_type] = nil
    end

    def handle_delete(args)
      return unless args.inputs.keyboard.key_down.d

      stage_editor = args.state.stage_editor
      stage_objects(args, stage_editor[:selected_type]).delete(stage_editor[:selected])
      deselect_object(args)
    end

    def stage_objects(args, type)
      case type
      when :wall
        args.state.stage[:walls]
      when :spawn_zone
        args.state.stage[:spawn_zones]
      end
    end

    def handle_rotate(args)
      return unless args.inputs.keyboard.key_down.r

      selected = args.state.stage_editor[:selected]
      selected[:w], selected[:h] = selected[:h], selected[:w]
      clamp_to_stage(args, selected)
    end

    def handle_size_change(args)
      selected = args.state.stage_editor[:selected]
      return unless selected

      long_dimension = selected[:w] >= selected[:h] ? :w : :h

      key_held = args.inputs.keyboard.key_held
      min_length = 100
      if key_held.l
        selected[long_dimension] += 10
      elsif key_held.s
        selected[long_dimension] -= 10
        selected[long_dimension] = min_length if selected[long_dimension] < min_length
      end

      clamp_to_stage(args, selected)
    end

    def handle_drag(args)
      stage_editor = args.state.stage_editor
      mouse = args.inputs.mouse
      mouse_position = mouse_in_world(args)
      selected = stage_editor[:selected]

      if stage_editor[:dragged]
        if mouse.button_left
          dragged = stage_editor[:dragged]
          selected[:x] = dragged[:dragged_start_x] + (mouse_position[:x] - dragged[:mouse_start_x])
          selected[:y] = dragged[:dragged_start_y] + (mouse_position[:y] - dragged[:mouse_start_y])
          selected[:x] = selected[:x].idiv(10) * 10
          selected[:y] = selected[:y].idiv(10) * 10
          clamp_to_stage(args, selected)
        else
          stage_editor[:dragged] = nil
        end
      else
        if selected && mouse.button_left
          stage_editor[:dragged] = {
            mouse_start_x: mouse_position[:x], mouse_start_y: mouse_position[:y],
            dragged_start_x: selected[:x], dragged_start_y: selected[:y]
          }
        end
      end
    end

    def handle_new_wall(args)
      return unless args.inputs.keyboard.key_down.n

      mouse = mouse_in_world(args)
      new_wall_length = 300
      new_wall_thickness = 40
      new_wall = {
        x: mouse[:x] - new_wall_length.idiv(2),
        y: mouse[:y] - new_wall_thickness.idiv(2),
        w: new_wall_length,
        h: new_wall_thickness
      }
      args.state.stage[:walls] << new_wall
      select_object args, :wall, new_wall
      clamp_to_stage(args, new_wall)

      make_wallRts(args)
    end

    def handle_new_spawn_zone(args)
      return unless args.inputs.keyboard.key_down.z

      mouse = mouse_in_world(args)
      new_spawn_zone_length = 200
      new_spawn_zone_width = 400
      new_spawn_zone = {
        x: mouse[:x] - new_spawn_zone_length.idiv(2),
        y: mouse[:y] - new_spawn_zone_width.idiv(2),
        w: new_spawn_zone_length,
        h: new_spawn_zone_width
      }
      args.state.stage[:spawn_zones] << new_spawn_zone
      select_object args, :spawn_zone, new_spawn_zone
      clamp_to_stage(args, new_spawn_zone)
    end

    def handle_save(args)
      return unless args.inputs.keyboard.key_down.one

      $gtk.serialize_state 'stage', args.state.stage
      $gtk.notify! 'Saved!'
    end

    def handle_change_mode(args)
      return unless args.inputs.keyboard.key_down.tab

      stage_editor = args.state.stage_editor
      modes = %i[walls nav_grid]
      current_mode_index = modes.index stage_editor[:mode]
      stage_editor[:mode] = modes[(current_mode_index + 1) % modes.length]
    end

    def clamp_to_stage(args, wall)
      bounds = stage_bounds(args.state.stage)
      wall[:x] = wall[:x].clamp(bounds.left, bounds.right - wall[:w])
      wall[:y] = wall[:y].clamp(bounds.bottom, bounds.top - wall[:h])
    end

    def render(args)
      render_base(args)
      render_stage(args)
      render_enemies(args)
      render_turrets(args)

      render_ui(args)
      case args.state.stage_editor[:mode]
      when :walls
        render_selection(args)
      when :nav_grid
        render_nav_grid(args)
        render_path_from_mouse(args)
      end
    end

    def render_ui(args)
      stage_editor = args.state.stage_editor
      args.outputs.primitives << {
        x: 1280, y: 720, text: 'STAGE EDITOR', size_enum: 10, alignment_enum: 2
      }.label!
      args.outputs.primitives << {
        x: 1280, y: 680, text: "Mode: #{stage_editor[:mode]}", size_enum: 6, alignment_enum: 2
      }.label!
      commands = ['(TAB) Change mode, (0) Back to game']
      case stage_editor[:mode]
      when :walls
        commands << '(1) Save'
        if stage_editor[:selected]
          commands << '(D)elete, (R)otate, (L)onger, (S)horter'
        else
          commands << '(N)ew wall, New Spawn (Z)one'
        end
      when :nav_grid
      end

      args.outputs.primitives << { x: 0, y: 25, text: commands.join(', ') }.label!
    end

    def render_selection(args)
      selected = args.state.stage_editor[:selected]
      return unless selected

      rect_on_screen = Camera.transform(args.state.camera, selected)
      args.outputs.primitives << fat_border(rect_on_screen, line_width: 4, r: 255, g: 0, b: 0)
    end

    def render_nav_grid(args)
      mouse_position = mouse_in_world(args)
      grid = args.state.navigation_grid[:grid]
      grid_type = args.state.navigation_grid[:type]

      area = { x: mouse_position[:x] - 200, y: mouse_position[:y] - 200, w: 400, h: 400 }
      grid_points = grid_type.grid_points_in_rect(grid, area)

      camera = args.state.camera
      cost_so_far = args.state.navigation_grid[:cost_so_far]
      grid_points.each do |point|
        world_point = grid_type.world_coordinates grid, point
        point_on_screen = Camera.transform camera, world_point
        args.outputs.primitives << point_on_screen.to_label(
          text: cost_so_far[point].to_s, r: 255, g: 0, b: 0, size_px: 20 * camera[:zoom], alignment_enum: 2
        )
      end
    end

    def render_path_from_mouse(args)
      position = mouse_in_world(args)
      stage_bounds = stage_bounds(args.state.stage)
      return unless position.inside_rect? stage_bounds

      camera = args.state.camera
      base = args.state.base
      position_on_screen = Camera.transform camera, position
      until position.intersect_rect? base
        last_position_on_screen = position_on_screen
        move_enemy(args, position)
        position_on_screen = Camera.transform camera, position
        args.outputs.primitives << last_position_on_screen.line!(x2: position_on_screen[:x], y2: position_on_screen[:y], r: 0, g: 0, b: 255)
      end
    end
  end
end
