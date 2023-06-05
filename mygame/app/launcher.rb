module Launcher
  class << self
    def build
      {state: :idle, power: 0, direction: nil, max_power: 300}
    end

    def control_launcher args
      m = args.inputs.mouse
      launcher = args.state.launcher

      case launcher[:state]
      when :idle
        if m.click && can_launch?(args)
          launcher[:state] = :charging
          launcher[:power] = 0
          launcher[:charge_sign] = 1
        end
      when :charging
        launcher[:direction] = calculate_launcher_direction(args, m)
        launcher[:angle] = angle_from_vector(launcher[:direction])
        if m.click
          type = args.state.selected_turret_type
          launched_turret = build_launched_turret(args, type)
          args.state.launched_turrets << launched_turret
          args.state.essence_held -= Turret.definition(type)[:cost]
          launcher[:state] = :idle
          launcher[:power] = 0
        end
      end
    end

    def build_launched_turret(args, turret_type)
      base = args.state.base
      launcher = args.state.launcher
      {
        x: base.x, y: base.y,
        w: 100, h: 100,
        dx: launcher[:direction].x, dy: launcher[:direction].y,
        logical_x: base.x, logical_y: base.y,
        pow: launcher[:power] / 5,
        type: turret_type,
        angle: launcher[:angle]
      }
    end

    def can_launch?(args)
      args.state.essence_held >= Turret.definition(args.state.selected_turret_type)[:cost]
    end

    def update(args)
      launcher = args.state.launcher
      return unless launcher[:state] == :charging

      # tick up the current charge state
      charge_speed = 5
      min = 0
      launcher[:power] += charge_speed * launcher[:charge_sign]
      if launcher[:power] > launcher[:max_power]
        launcher[:power] = launcher[:max_power]
        launcher[:charge_sign] = -1
      elsif launcher[:power] < min
        launcher[:power] = min
        launcher[:charge_sign] = 1
      end
    end

    def calculate_launcher_direction(args, mouse)
      base_on_screen = Camera.transform args.state.camera, args.state.base
      direction_between(base_on_screen, mouse)
    end

    def charge_bar_sprite(launcher)
      bottom = 50
      top = 50 + launcher[:max_power]
      x = 1100
      [
        { x: x, y: bottom, x2: x + 100, y2: bottom }.line!,
        { x: x, y: top, x2: x + 100, y2: top }.line!,
        { x: x, y: bottom, w: 100, h: top - bottom, r: 0, g: 0, b: 0, a: 100, path: :pixel }.sprite!,
        {
          x: x + 25, y: bottom, w: 50, h: launcher[:power],
          path: :pixel, r: 0, g: 200, b: 0
        }.sprite!
      ]
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
