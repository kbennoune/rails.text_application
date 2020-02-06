module UnicodeFormatting
  # SPACER = [729].pack('U*')
  SPACER = [183].pack('U*')
  REPLACEMENTS = /[\p{Pe}\p{Space}\?\=\&\"\'\＠\『\』\〖\〗\〘\〙\「\」\〈\〉\《\》\【\】\〔\〕\⦗\⦘\⟦\⟧\⟨\⟩\⟪\⟫\⟮\⟯\⟬\⟭\⌈\⌉\⌊\⌋\⦇\⦈\⦉\⦊]/
  # [\p{Pe}\p{Space}\?\=\&\"\＠\'\『\』\〖\〗\〘\〙\「\」\〈\〉\《\》\【\】\〔\〕\⦗\⦘\⟦\⟧\⟨\⟩\⟪\⟫\⟮\⟯\⟬\⟭\⌈\⌉\⌊\⌋\⦇\⦈\⦉\⦊]
  class << self
    def url_escape(string)
      string.dup.gsub(/ /,SPACER).gsub(REPLACEMENTS) do |sequence|
        (sequence.unpack('C*').map { |c| "%" + ("%02x" % c).upcase }).join
      end
    end

    def url_unescape(string)
      Addressable::URI.unencode_component(respace(string))
    end

    def respace(string)
      string.gsub(SPACER,' ')
    end

    def format(type, string)
      FORMATTERS[ type ].format( string )
    end

    def dotted_underline(string)
      string.each_codepoint.inject([]){|acc,c|
        acc << c
        acc << 8424
        acc
      }.pack('U*')
    end

    def underline(string)
      string.each_codepoint.inject([]){|acc,c|
        acc << c
        acc << 819
        acc
      }.pack('U*')
    end

    def strikethrough(string)
      string.each_codepoint.inject([]){|acc,c|
        acc << c
        acc << 821
        acc
      }.pack('U*')
    end
  end

  FORMATTERS = {
    bold: UnicodeFormatting::SansSerifBold,
    italic: UnicodeFormatting::SansSerifItalic,
    bold_italic: UnicodeFormatting::SansSerifBoldItalic,
    monospace: UnicodeFormatting::Monospace,
    small_caps: UnicodeFormatting::SmallCaps
  }

end
