module UnicodeFormatting
  module Helper
    def bold(string)
      UnicodeFormatting.format(:bold, string)
    end

    def italic(string)
      UnicodeFormatting.format(:italic, string)
    end

    def bold_italic(string)
      UnicodeFormatting.format(:bold_italic, string)
    end

    def underline(string)
      UnicodeFormatting.underline(string)
    end

    def dotted_underline(string)
      UnicodeFormatting.dotted_underline(string)
    end

    def monospace(string)
      UnicodeFormatting.format(:monospace, string)
    end

    def small_caps(string)
      UnicodeFormatting.format(:small_caps, string)
    end
  end
end
