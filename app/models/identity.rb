class Identity < ApplicationRecord
  belongs_to :user

  serialize :scopes, Array
end
