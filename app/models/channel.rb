class Channel < ApplicationRecord
  belongs_to :business
  belongs_to :started_by_person, class_name: 'Person', optional: true
  has_many :channel_people
  has_many :people, ->{ distinct }, through: :channel_people do |x1, x2|
    def unique_push(*records, &finder)
      Person.transaction do
        records.flatten.find_all do |record|
          begin
            self.push record
          rescue ActiveRecord::RecordNotUnique => e
            finder.present? ? finder.call(record) : false
          end
        end
      end
    end
  end

  has_many :text_messages

  has_many :channel_groups
  has_many :text_groups, through: :channel_groups

  ROOT_TOPIC = 'root'
  CHAT_TOPIC = 'chat'
  ROOM_TOPIC = 'room'
  POLL_TOPIC = 'poll'
  INVITE_TOPIC = 'invite'

  scope :permanent, ->{ where( topic: ROOM_TOPIC ) }
  scope :matching_active, ChannelScopes.matching_active
  scope :active, ChannelScopes.active

  def mobile_recipients
    people
  end

  def text_group_names
    text_groups.map(&:name)
  end

  class << self
    def create_group_channel(business, text_group, started_by: nil, topic: ROOM_TOPIC)
      create! group_channel_args( business, text_group, topic, started_by )
    end

    def build_group_channel(business, text_group, started_by: nil, topic: ROOM_TOPIC)

      text_group.channels.build( group_channel_args( business, text_group, topic, started_by ).except(:channel_groups) )
    end

    def group_channel_args( business, text_group, topic, started_by_person )
      { business: business, topic: topic, started_by_person: started_by_person, channel_groups: [ChannelGroup.new( text_group: text_group )] }
    end
  end
end
