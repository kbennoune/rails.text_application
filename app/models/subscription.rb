class Subscription < ApplicationRecord
  belongs_to :business, optional: true
end
