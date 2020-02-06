module UnicodeFormatting
  module Monospace
    include Font

    CAPS_OFFSET = 120367
    LOWER_OFFSET = 120361
    NUM_OFFSET = 120774

    def caps_offset
      CAPS_OFFSET
    end

    def lower_offset
      LOWER_OFFSET
    end

    def num_offset
      NUM_OFFSET
    end

    extend self
  end
end
