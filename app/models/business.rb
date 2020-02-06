class Business < ApplicationRecord
  has_one :root_channel, ->{ where(topic: ::Channel::ROOT_TOPIC ) }, class_name: 'Channel', foreign_key: :business_id
  has_many :channels

  has_many :text_groups
  has_many :subscriptions

  scope :administered_by, ->(person){ joins( :business_admins ).where( business_admins: {person_id: person.id} ).distinct }

  has_many :business_admins
  has_many :admins, through: :business_admins, class_name: 'Person', source: 'person'

  def display_name
    name || facebook_place_name
  end

  def managing_google_identities
    Identity.joins(
      user: {facebook_identity: :managed_facebook_places}
    ).where(
      provider: 'google',
      managed_facebook_places: {facebook_place_id: facebook_place_id}
    )
  end

  def administered_by?( person )
    person.kind_of?(Person) && Business.administered_by(person).where( business_admins: { business_id: self.id } ).present?
  end
end
