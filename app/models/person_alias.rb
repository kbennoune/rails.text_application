class PersonAlias < ApplicationRecord
  belongs_to :real, class_name: 'Person'
  belongs_to :alias, class_name: 'Person'

  STATUS_LISTEN = 'active'
  STATUS_SLEEP = 'inactive'

  # Default can't be set because it overrides status
  attribute :status

end
