module Base
  class << self
    def build(stage)
      stage[:base_position].merge(
        w: 200, h: 200,
        anchor_x: 0.5, anchor_y: 0.5,
        health: 100
      )
    end

    def dead?(base)
      base.health <= 0
    end

    def sprite(base)
      base.to_sprite(
        path: "sprites/slimeKing.png",
        r:255,
        b:255,
        g:255
        #r: base.health.remap(0, 100, 255, 0),
        #g: base.health.remap(0, 100, 0, 255),
        #b: 40
      )
    end

    def health_label(base)
      {
        text: base.health,
        x: base[:x], y: base[:y] + 140,
        size_px: 40,
        alignment_enum: 1,
        r: 0, g: 0, b: 0
      }
    end
  end
end
