class TopicGroupPerson < ApplicationRecord
  belongs_to :person
  belongs_to :topic_group
end
