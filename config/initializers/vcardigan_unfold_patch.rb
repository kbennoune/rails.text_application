class ::VCardigan::VCard
  private

  def unfold(card)
    unfolded = []

    prior_line = nil
    card.lines do |line|
      line.chomp!
      # If it's a continuation line, add it to the last.
      # If it's an empty line, drop it from the input.
      if (line =~ /^[ \t]/) || (line =~ /^[^:]*$/)
        unfolded[-1] << line[1, line.size-1]
      elsif line =~ /(^BEGIN:VCARD$)|(^END:VCARD$)/
      elsif prior_line && (prior_line =~ UNTERMINATED_QUOTED_PRINTABLE)
        # Strip the trailing = off prior line, then append current line
        unfolded[-1] = prior_line[0, prior_line.length-1] + line
      elsif line =~ /^$/
      else
        unfolded << line
      end
      prior_line = unfolded[-1]
    end

    unfolded
  end
end
