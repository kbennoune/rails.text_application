class SmsLinksController < ApplicationController
  skip_before_action :verify_authenticity_token
  helper_method :application_phone_number, :body_param, :call_to_action, :os_separator
  layout 'sms'

  def show
    
  end

  def application_phone_number
    @application_phone_number = if params[:phone_number_id]
      ApplicationPhoneNumber.find params[:phone_number_id]
    else
      ApplicationPhoneNumber.first
    end
  end


  def body_param
    @body_param ||= {
      'a' => "#{params[:additional_param]}\n⟬Add name after the ＠⟭\n\n@ "
    }[ params[:id] ]
  end

  def call_to_action
    @call_to_action ||= {
      'a' => "Join!"
    }[ params[:id] ]
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
