class SmsInvitesController < ApplicationController
  skip_before_action :verify_authenticity_token
  helper_method :invitations, :root_channel, :os_separator, :invite_url
  layout 'sms'

  def index
    raise unless params[:secure_code] == Rails.application.config.x.secure_code
  end

  def root_channel
    @root_channel ||= Channel.where( business_id: business_id, topic: ::Channel::ROOT_TOPIC ).first
  end

  def invitations
    @invitations ||= ServiceInvitation.where(
      service_location: root_channel
    ).where(
      ServiceInvitation.arel_table[:expires_at].gt(Time.zone.now + 2.weeks)
    )
  end

  def business_id
    params[:business_id]
  end

  def invite_url(invite_code)
    channel_number = ApplicationPhoneNumber.first.number

    ChannelTopics::Person::Invite.invite_link( channel_number, invite_code, separator: os_separator, skip_encode: /\W/ ).html_safe
  end

  def os_separator
    case
    when browser.platform.ios? && browser.platform.version.to_i >= 7
      '&'
    else
      '?'
    end
  end
end
