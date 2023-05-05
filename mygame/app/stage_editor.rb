module StageEditor
  class << self
    def start(args)
      args.state.stage_editor = { selected: nil }
    end

    def tick(args)
      process_inputs(args)
      update(args)
      render(args)
    end

    def handle_onoff(args)
      if args.inputs.keyboard.key_down.zero
        args.state.scene = args.state.scene == :game ? :stage_editor : :game
      end
    end

    private

    def process_inputs(args)
      CameraMovement.control_camera(mouse: args.inputs.mouse, camera: args.state.camera)
      handle_onoff(args)
      handle_selection(args)
      if args.state.stage_editor[:selected]
        handle_delete(args)
        handle_rotate(args)
      end

    end

    def handle_selection(args)
      mouse = args.inputs.mouse
      return unless mouse.click

      mouse_point = { x: mouse.x, y: mouse.y, w: 0, h: 0 }
      mouse_in_world = Camera.to_world_coordinates!(args.state.camera, mouse_point)
      args.state.stage_editor[:selected] = args.state.stage[:walls].find { |wall|
        mouse_in_world.inside_rect?(wall)
      }
    end

    def handle_delete(args)
      return unless args.inputs.keyboard.key_down.d

      args.state.stage[:walls].delete(args.state.stage_editor[:selected])
      args.state.stage_editor[:selected] = nil
    end

    def handle_rotate(args)
      return unless args.inputs.keyboard.key_down.r

      selected = args.state.stage_editor[:selected]
      selected[:w], selected[:h] = selected[:h], selected[:w]
    end

    def update(args)
    end

    def render(args)
      render_player_area(args)
      render_stage(args)
      render_enemies(args)
      render_turrets(args)

      render_ui(args)
      render_selection(args)
    end

    def render_ui(args)
      args.outputs.primitives << {
        x: 1280, y: 720, text: 'STAGE EDITOR', size_enum: 10, alignment_enum: 2
      }.label!
      state_editor = args.state.stage_editor
      commands = []
      if state_editor[:selected]
        commands << '(D)elete, (R)otate'
      end
      args.outputs.primitives << { x: 0, y: 25, text: commands.join(', ') }.label!
    end

    def render_selection(args)
      selected = args.state.stage_editor[:selected]
      return unless selected

      rect_on_screen = Camera.transform(args.state.camera, selected)
      args.outputs.primitives << fat_border(rect_on_screen, line_width: 4, r: 255, g: 0, b: 0)
    end

    def fat_border(rect, line_width:, **values)
      [
        { x: rect.x - line_width, y: rect.y - line_width, w: rect.w + line_width * 2, h: line_width, path: :pixel }.sprite!(values),
        { x: rect.x - line_width, y: rect.y - line_width, w: line_width, h: rect.h + line_width * 2, path: :pixel }.sprite!(values),
        { x: rect.x - line_width, y: rect.y + rect.h, w: rect.w + line_width * 2, h: line_width, path: :pixel }.sprite!(values),
        { x: rect.x + rect.w, y: rect.y - line_width, w: line_width, h: rect.h + line_width * 2, path: :pixel }.sprite!(values)
      ]
    end
  end
end
