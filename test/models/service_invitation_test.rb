require 'test_helper'

class ServiceInvitationTest < ActiveSupport::TestCase
  test 'defaults to expiring at a specific time' do
    invitation = ServiceInvitation.new
    assert_in_delta Time.now + 1.month, invitation.expires_at, 1.minute

    longer_invitation = ServiceInvitation.new expires_at: Time.now + 100.years
    assert_in_delta Time.now + 100.years, longer_invitation.expires_at, 1.minute
  end

  test 'adding service groups' do
    groups_to_add = [TextGroup.new( id: 1000003, name: 'first' ), TextGroup.new( id: 10001, name: 'first' )]

    invitation = ServiceInvitation.new

    invitation.service_groups_to_add = groups_to_add

    assert_equal [['TextGroup', groups_to_add[1].id],['TextGroup', groups_to_add[0].id]], invitation.service_groups

    TextGroup.stub(:find, ->(*ids){ groups_to_add.find_all{|tg| ids.include?(tg.id) } }) do
      assert_equal invitation.service_groups_to_add, groups_to_add
    end
  end
end
