module Waves
  class << self
    def tick(args)
      Enemies.spawn(args, Enemies::TYPES.keys.sample) if args.tick_count.mod_zero?(60)
    end
  end
end
