class User < ApplicationRecord
  has_one :facebook_identity, ->{ where( provider: 'facebook' ) }, class_name: 'Identity'

  has_many :google_identities, ->{ where( provider: 'google') }, class_name: 'Identity'

  delegate :name, to: :facebook_identity, prefix: false, allow_nil: true

  delegate :name, :email, to: :facebook_identity, prefix: :facebook, allow_nil: true

  delegate :oauth_token, to: :facebook_identity, prefix: :facebook
end
