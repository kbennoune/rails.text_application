class ServiceInvitation < ApplicationRecord
  EXPIRATION_LENGTH = 1.month

  belongs_to :service_location, polymorphic: true
  belongs_to :inviting_person, class_name: 'Person', optional: true
  belongs_to :invited_person, class_name: 'Person', optional: true

  delegate :mobile, to: :inviting_person, prefix: true, allow_nil: true

  serialize :service_groups, JSON
  attribute :expires_at, :datetime, default: ->{ Time.now + EXPIRATION_LENGTH }

  def service_groups_to_add
    (service_groups || []).group_by(&:first).map{|k,v| k.constantize.find(*v.map(&:last)) }.flatten
  end

  def service_groups_to_add=(groups)
    self.service_groups = groups.map{|group| [group.class.name, group.id] }.sort
  end
end
