module Base
  class << self
    def build(stage)
      stage[:base_position].merge(
        x: 0, y: 0, w: 200, h: 200,
        anchor_x: 0.5, anchor_y: 0.5,
        health: 100
      )
    end

    def dead?(base)
      base.health <= 0
    end

    def sprite(base)
      base.to_sprite(
        path: :pixel,
        r: 255 - base.health * 255 / 100,
        g: base.health * 255 / 100,
        b: 40)
    end

    def health_label(base)
      {
        text: base.health,
        x: 0, y: 140,
        size_px: 40,
        alignment_enum: 1,
        r: 0, g: 0, b: 0
      }
    end
  end
end
