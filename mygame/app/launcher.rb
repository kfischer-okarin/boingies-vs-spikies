module Launcher
  class << self
    def build
      {state: :idle, power: 0, direction: nil}
    end

    def control_launcher args
      m = args.inputs.mouse
      launcher = args.state.launcher

      case launcher[:state]
      when :idle
        if m.click
          launcher[:state] = :charging
          launcher[:power] = 0
        end
      when :charging
        launcher[:direction] = calculate_launcher_direction(args, m)
        launcher[:angle] = angle_from_vector(launcher[:direction])
        if m.click
          # should extract this back to main?
          args.state.launched_turrets << build_turret(args)
          launcher[:state] = :idle
          launcher[:power] = 0
        end
      end
    end

    def update(args)
      launcher = args.state.launcher
      return unless launcher[:state] == :charging

      # tick up the current charge state
      args.state.maxChargePower ||= 720 - 100
      launcher[:power] += 10
      if launcher[:power] > args.state.maxChargePower
        launcher[:power] = args.state.maxChargePower
      end
    end

    def calculate_launcher_direction(args, mouse)
      base_on_screen = Camera.transform args.state.camera, args.state.base
      direction_between(base_on_screen, mouse)
    end

    def charge_bar_sprite(launcher)
      {
        x: 1100, y: 50, w: 50, h: launcher[:power],
        path: :pixel, r: 0, g: 200, b: 0
      }.sprite!
    end

    def direction_marker_sprite(args)
      launcher = args.state.launcher
      camera = args.state.camera
      base = args.state.base

      if launcher[:direction]
        # Camera.transforms are made on main#render_*. we should move this bit and only return what to draw?
        # also, the line is always 200px inspite of zoom level, so we probalby want to transform it before
        # rendering
        base_on_screen = Camera.transform camera, base
        x = base_on_screen.x
        y = base_on_screen.y
        length = 200

        {
          x: x,
          y: y,
          x2: x + launcher[:direction].x * length,
          y2: y + launcher[:direction].y * length
        }.line!
      end
    end

    def charging?(launcher)
      launcher.state == :charging
    end
  end
end
