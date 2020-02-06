class TextGroup < ApplicationRecord
  belongs_to :business
  belongs_to :created_by_person, class_name: 'Person', optional: true

  has_many :text_group_people, dependent: :destroy
  has_many :people, through: :text_group_people

  has_many :channel_groups, dependent: :destroy
  has_many :channels, through: :channel_groups

  has_many :permanent_channels, ->{ permanent }, through: :channel_groups, autosave: true, source: :channel
  has_many :permanent_channel_groups, ->{ readonly.joins(:channel).where( channels: { topic: ::Channel::ROOM_TOPIC }) }, class_name: 'ChannelGroup'

  fuzzily_searchable :name, async: true

  def display_name
    name
  end

  def mention_code(within:, fuzzy_match_cutoff: 0.3)
    channel = within
    names = display_name.downcase.split(/\W/)

    short_name = names.each_with_index do |name, i|
      candidate = names[0..i].join
      match = Trigram.channel_matches_for(channel, candidate ).where( owner_type: self.class.name ).first
      if candidate.size > 4 || (names.size + 1 == i)
        if match && match.owner_id == self.id && (match.matches.to_f/match.score.to_f > fuzzy_match_cutoff)
          # if the result matches this object then return the candidate and end the loop
          break candidate
        end
      end
    end

    if !short_name.kind_of?(::String)
      short_name = display_name.gsub(/\s/,'')
    end

    "@#{short_name}"
  end
end
