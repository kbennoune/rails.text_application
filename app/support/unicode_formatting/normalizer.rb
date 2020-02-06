module UnicodeFormatting
  module Normalizer
    # Combined forms for spanish
    MAPPING = {
      "á"=>"á", "é"=>"é", "í"=>"í", "ó"=>"ó", "ú"=>"ú", "ñ"=>"ñ", "Ñ"=>"Ñ",
      "ü"=>"ü", "Ü"=>"Ü",
      "Á"=>"Á", "É"=>"É", "Í" => "Í", "Ó" => "Ó", "Ú" => "Ú"
    }

    def normalize(string)
      string.split('').map{|c| normalize_char(c) }.join('')
    end

    def normalize_char(char)
      MAPPING[ char ] || char
    end

    extend self
  end
end
