module StageEditor
  class << self
    def start(args)
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
    end

    def update(args)
    end

    def render(args)
      render_player_area(args)
      render_stage(args)
      render_enemies(args)
      render_turrets(args)

      render_ui(args)
    end

    def render_ui(args)
      args.outputs.primitives << {
        x: 1280, y: 720, text: 'STAGE EDITOR', size_enum: 10, alignment_enum: 2
      }.label!
    end
  end
end
