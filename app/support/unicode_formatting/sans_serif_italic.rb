module UnicodeFormatting
  module SansSerifItalic
    include UnicodeFormatting::Font
    # Mathematical Sans-serif Bold Capital
    CAPS_OFFSET = 120263
    LOWER_OFFSET = 120257
    NUM_OFFSET = 120754

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
