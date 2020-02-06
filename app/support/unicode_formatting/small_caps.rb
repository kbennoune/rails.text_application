module UnicodeFormatting
  module SmallCaps
    include UnicodeFormatting::Font

    def transformations
      @transformations ||= begin
        mapping = {}
        alphabet = "ᴀʙᴄᴅᴇғɢʜɪᴊᴋʟᴍɴᴏᴘ𝚀ʀѕᴛᴜᴠᴡxʏᴢ".codepoints
        numbers = "𝟢𝟣𝟤𝟥𝟦𝟧𝟨𝟩𝟪𝟫".codepoints
        ('A'..'Z').to_a.each_with_index do |letter, idx|
          mapping[ letter.codepoints[0] ] = alphabet[ idx ]
        end

        ('a'..'z').to_a.each_with_index do |letter, idx|
          mapping[ letter.codepoints[0] ] = alphabet[ idx ]
        end

        (0..9).to_a.each do |num|
          mapping[ num.to_s.codepoints[0] ] = numbers[ num ]
        end

        mapping
      end
    end

    extend self
  end
end
