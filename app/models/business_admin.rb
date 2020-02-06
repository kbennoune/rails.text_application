class BusinessAdmin < ApplicationRecord
  belongs_to :business
  belongs_to :person
end
