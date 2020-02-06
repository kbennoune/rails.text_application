module ChannelTopics
  module PeopleManager

    NAMES_REGEX = /(?:(?!=@)[[:alpha:]][^\n,:@]{3,}|@[[:alpha:]][^\n\S,:]{3,})(?=,|\s*\n|\s*:|\s*$)|(?:@[[:alpha:]]{3,})(?:$|\s:|\s)/

    def included_people
      @included_people ||= included_participant_names.map{ |name|
        match = Trigram.channel_matches_for(root_channel, name).first
        if match && (match.matches.to_f/match.score.to_f > fuzzy_match_cutoff )
          match.owner
        end
      }.compact

    end

    def fuzzy_match_cutoff
      0.25
    end

    def included_participant_names
      # replace and's with , to allow better scanning
      message_name_portion.gsub(/(?<=\s)and(?=\s)/,',').scan(NAMES_REGEX).map(&:strip)
    end

    def message_name_portion
      message.message_text
    end
  end
end
