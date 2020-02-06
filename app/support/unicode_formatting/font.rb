module UnicodeFormatting
  module Font
    def format(string)
      normalized(string).codepoints.inject([]){|new_codepoints, codepoint|
        new_codepoints << transform(codepoint)
      }.pack('U*')
    end

    def normalized(string)
      ::UnicodeFormatting::Normalizer.normalize(string)
    end

    def transform(codepoint)
      transformations[ codepoint ] || codepoint
    end

    def transformations
      @transformations ||= begin
        mapping = {}
        ('A'..'Z').each do |letter|
          codepoint = letter.codepoints.first
          mapping[codepoint] = codepoint + caps_offset
        end

        ('a'..'z').each do |letter|
          codepoint = letter.codepoints.first
          mapping[codepoint] = codepoint + lower_offset
        end

        ('1'..'9').each do |letter|
          codepoint = letter.codepoints.first
          mapping[codepoint] = codepoint + num_offset
        end

        mapping
      end
    end
  end
end
