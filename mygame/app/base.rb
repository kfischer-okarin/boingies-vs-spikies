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

    def health_bar_sprites(base)
      bar_total_width = 200
      max_health = 100
      bar_rect = { x: base[:x] - (bar_total_width / 2), y: base[:y] + 60, w: bar_total_width, h: 30 }
      [
        bar_rect.to_sprite(r: 150, g: 0, b: 0, path: :pixel),
        bar_rect.to_sprite(w: (base.health / max_health.to_f) * bar_total_width, r: 0, g: 150, b: 0, path: :pixel)
      ]
    end
  end
end
