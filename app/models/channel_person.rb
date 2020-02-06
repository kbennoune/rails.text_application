class ChannelPerson < ApplicationRecord
  belongs_to :person
  belongs_to :channel
  belongs_to :application_phone_number, default: ->{ ApplicationPhoneNumber.next_available(self.person, self.channel, self) }
  belongs_to :added_from_text_group, optional: true, class_name: 'TextGroup'

  delegate :number, to: :application_phone_number, allow_nil: true, prefix: :channel_phone
  delegate :mobile, :name, to: :person, allow_nil: true, prefix: :person

  scope :active, ->{ where(inactive: [nil, false]).where( ChannelPerson.arel_table[:application_phone_number_id].not_eq(nil)) }

  alias_method :sms_number, :person_mobile

  delegate :preferred_language, :preferred_locale, to: :person

  class << self
    def expanded_recipients
      eager_load(person: :active_real_people).all.map{|r| r.person.active_real_people.present? ? r.person.active_real_people.map{|p| self.new(r.attributes.merge(id: nil, person_id: nil, person: p)).tap(&:readonly!) } : r }.flatten
    end
  end

  # These should be refactored into relations
  def root_application_phone_number
    root_channel_person.try(:application_phone_number).try(:number)
  end

  def root_channel_person
    business_id = channel.business_id

    ChannelPerson.joins(:channel).where( person_id: person_id, channels: {business_id: business_id, topic: Channel::ROOT_TOPIC}).first
  end
end
