module UnicodeFormatting
  module SansSerifBold
    include UnicodeFormatting::Font
    # Mathematical Sans-serif Bold Capital
    CAPS_OFFSET = 120211
    LOWER_OFFSET = 120205
    NUM_OFFSET = 120764

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
