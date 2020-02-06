module ChannelTopics
  module Alias
    class Set < ChannelTopics::Processor

      def call
        PersonAlias.transaction do
          alias_people.each{|alias_person|
            alias_person.inactive_real_people = alias_person.active_real_people
            alias_person.active_real_people = new_real_people
            alias_person.save!
          }
        end
      end

      def alias_people
        parser.recipients.find_all{|p| p.mobile.blank? }
      end

      def new_real_people
        parser.recipients.find_all{|p| !p.mobile.blank? }
      end

      def parser
        @parser ||= ChannelMessageParser.new(message.message_text) do |potential_recipients|
          potential_recipients.map{ |match_text|
            name = match_text.gsub(/^@/,'')

            match = Trigram.channel_matches_for(channel, name).first
            if match && (match.matches.to_f/match.score.to_f > 0.25)
              [ name, match.owner ]
            end
          }.compact.to_h
        end
      end
    end
  end
end
