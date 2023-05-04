def tick(args)
  setup(args) if args.tick_count.zero?

  render(args)
end

def setup(args)
  stage_boundaries = [
    { x: -10, y: -10, w: 1300, h: 10 },
    { x: -10, y: 720, w: 1300, h: 10 },
    { x: -10, y: -10, w: 10, h: 740 },
    { x: 1280, y: -10, w: 10, h: 740 },
  ]
  args.state.walls = stage_boundaries + [
    { x: 400, y: 100, w: 40, h: 520 },
    { x: 600, y: 0, w: 40, h: 400 },
    { x: 600, y: 570, w: 40, h: 150 },
    { x: 800, y: 220, w: 40, h: 500 },
    { x: 1000, y: 0, w: 40, h: 500 }
  ]
end

def render(args)
  render_walls(args)
end

def render_walls(args)
  args.outputs.primitives << args.state.walls.map { |wall|
    wall.to_sprite(path: :pixel, r: 0, g: 0, b: 0)
  }
end

$gtk.reset
