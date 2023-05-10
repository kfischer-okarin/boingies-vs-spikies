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

        digit = digit_base.to_label(
          x: (w / 2) - 2, y: size_px + y_offset, text: digit.to_s,
          r: 0xc3, g: 0x63, b: 0x34
        )
        shadow = digit.merge(
          x: digit[:x] + 5, y: digit[:y] - 3,
          r: 0, g: 0, b: 0
        )

        render_target.primitives << shadow
        render_target.primitives << digit
      end
    end

    RENDER_SCALE = 0.5

    def build_damage_number(x:, y:, amount:)
      digits = amount.to_i.to_s.chars.map(&:to_i)
      digit_sprites = digits.map { |digit|
        digit_sprite_base = DIGITS[digit]
        digit_sprite_base.to_sprite(
          y: y,
          w: digit_sprite_base[:w] * RENDER_SCALE,
          h: digit_sprite_base[:h] * RENDER_SCALE,
          angle: -10 + rand(20),
          anchor_x: 0.5, anchor_y: 0.5
        )
      }

      sprite_x = x + first_digit_offset(digit_sprites)
      digit_sprites.each_with_index do |digit_sprite, index|
        digit_sprite[:x] = sprite_x
        digit_sprite[:frames] = build_animation_frames(digit_sprite, index)
        sprite_x += digit_sprite[:w]
      end
      {
        digit_sprites: digit_sprites
      }
    end

    def first_digit_offset(digit_sprites)
      total_width = digit_sprites.sum(&:w)
      first_digit_width = digit_sprites.first.w
      -(total_width / 2) + (first_digit_width / 2)
    end

    def build_animation_frames(digit_sprite, index)
      # Simple version
      # [
      #   {
      #     values: {
      #       w: { from: 0, to: digit_sprite[:w] },
      #       h: { from: 0, to: digit_sprite[:h] }
      #     },
      #     duration: 20,
      #     easing: :smooth_stop_cube
      #   },
      #   {
      #     values: {
      #       a: { from: 255, to: 0 }
      #     },
      #     duration: 20
      #   }
      # ]

      # boingy boing boing
      target_y = digit_sprite[:y]
      [
        { duration: index * 5 }, # delay each digit a bit
        {
          values: {
            w: { from: 0, to: digit_sprite[:w] },
            h: { from: 0, to: digit_sprite[:h] },
            y: { from: target_y, to: target_y + 20 }
          },
          duration: 15,
          easing: :smooth_stop_cube
        },
        {
          values: {
            y: { from: target_y + 20, to: target_y }
          },
          duration: 10,
          easing: :quad
        },
        {
          values: {
            y: { from: target_y, to: target_y + 10 }
          },
          duration: 8,
          easing: :smooth_stop_cube
        },
        {
          values: {
            y: { from: target_y + 10, to: target_y },
          },
          duration: 6
        },
        {
          duration: 30
        },
        {
          values: {
            x: { from: digit_sprite[:x], to: digit_sprite[:x] - 30 * index },
            w: { from: digit_sprite[:w], to: 0 },
            a: { from: 255, to: 0 }
          },
          duration: 30
        }
      ]
    end

    def update_all(damage_numbers)
      damage_numbers.each do |damage_number|
        digit_sprites = damage_number[:digit_sprites]
        digit_sprites.each do |digit_sprite|
          run_animation_frames(digit_sprite, digit_sprite[:frames])
        end

        digit_sprites.reject! { |digit_sprite| digit_sprite[:frames].empty? }
      end

      damage_numbers.reject! { |damage_number| damage_number[:digit_sprites].empty? }
    end

    def run_animation_frames(hash, frames)
      frame = frames.first
      frame[:tick] ||= 0
      apply_animation_frame(hash, frame)
      frame[:tick] += 1
      frames.shift if frame[:tick] >= frame[:duration]
    end

    def apply_animation_frame(hash, frame)
      return unless frame[:values] # To support "empty frames" for delays

      frame[:values].each do |key, animation|
        lerp_value = Easing.ease(0, frame[:tick], frame[:duration], frame[:easing] || :identity)
        hash[key] = lerp_value.remap(0, 1, animation[:from], animation[:to])
      end
    end

    def render_all(args, damage_numbers)
      camera = args.state.camera
      args.outputs.primitives << damage_numbers.map { |damage_number|
        damage_number[:digit_sprites].map { |digit_sprite| Camera.transform camera, digit_sprite }
      }
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
