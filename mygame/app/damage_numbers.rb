module DamageNumbers
  DIGIT_H = 70

  DIGITS = {
    0 => { w: 55, h: DIGIT_H, path: :damage_digit0 },
    1 => { w: 70, h: DIGIT_H, path: :damage_digit1 },
    2 => { w: 65, h: DIGIT_H, path: :damage_digit2 },
    3 => { w: 55, h: DIGIT_H, path: :damage_digit3 },
    4 => { w: 60, h: DIGIT_H, path: :damage_digit4 },
    5 => { w: 60, h: DIGIT_H, path: :damage_digit5 },
    6 => { w: 55, h: DIGIT_H, path: :damage_digit6 },
    7 => { w: 60, h: DIGIT_H, path: :damage_digit7 },
    8 => { w: 60, h: DIGIT_H, path: :damage_digit8 },
    9 => { w: 55, h: DIGIT_H, path: :damage_digit9 }
  }

  class << self
    def setup(args)
      size_px = 70
      y_offset = 2
      digit_base = {
        size_px: size_px,
        alignment_enum: 1,
        font: 'fonts/SuperBubble.ttf'
      }
      DIGITS.each do |digit, definition|
        render_target = args.outputs[definition[:path]]
        w = definition[:w]
        h = definition[:h]
        render_target.width = w
        render_target.height = h
        render_target.primitives << digit_base.to_label(
          x: w / 2 + 3, y: size_px + y_offset - 3, text: digit.to_s,
          r: 0, g: 0, b: 0
        )
        render_target.primitives << digit_base.to_label(
          x: w / 2 - 2, y: size_px + y_offset, text: digit.to_s,
          r: 0xc3, g: 0x63, b: 0x34
        )
      end
    end

    # Used for previewing the generated sprites
    def debug_render_all(args)
      x = 100
      y = 200
      DIGITS.each_value do |definition|
        args.outputs.primitives << [
          definition.to_sprite(
            x: x, y: y,
            path: :pixel, r: 0, g: 200, b: 200, a: 200
          ),
          definition.to_sprite(x: x, y: y)
        ]
        x += definition[:w] + 5
      end
    end
  end
end

$gtk.reset
