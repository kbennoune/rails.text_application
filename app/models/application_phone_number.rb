class ApplicationPhoneNumber < ApplicationRecord
  DEFAULT_SUNSET_PERIOD = Rails.env.development? ? 4.seconds : 4.hours
  has_many :channel_people
  has_many :channels, through: :channel_people
  attribute :number, :phone_number

  scope :available_for_business, ApplicationPhoneNumberScopes.available_for_business

  # This can probably be sped up by right joining using topics
  # or by using a subselect.
  scope :next_available_number_query, ApplicationPhoneNumberScopes.next_available_number_query

  class << self
    def next_available(person, channel, channel_person, sunset_period: DEFAULT_SUNSET_PERIOD)
      new_number = next_available_number_query(sunset_period, person).first

      # This is where the reserved business numbers can access the scope
      # for_business with business id coming from the channel

      if new_number.blank?
        channel_person.errors.add(:application_phone_number_id, "There are no available numbers at this time.")
      end

      new_number
    end
  end
end
