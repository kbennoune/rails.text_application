module UnicodeFormatting
  module SansSerifBoldItalic
    include UnicodeFormatting::Font
    # Mathematical Sans-serif Bold Capital
    CAPS_OFFSET = 120315
    LOWER_OFFSET = 120309
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
