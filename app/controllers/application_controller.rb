class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  helper_method :meta_description_tag
  helper_method :navigation_breadcrumb, :current_user, :current_business, :flash_messages

  before_action :set_device_variant

  private
    def meta_description_tag
      attributes = { name: 'description', content: 'A scheduling app'}
      data = {}

      if respond_to?(:log_date, true)
        data[:date] = log_date
        data[:date_description] = log_date.strftime('%A, %B %-d')
      end

      attributes[:data] = data

      view_context.tag(:meta, attributes)
    end

    def navigation_breadcrumb
      {}
    end

    def flash_messages
      flash.to_hash.slice(:errors, :success, :notice)
    end

    def get_date_of_interest
      case
      when (date = flash[:date_of_interest]).kind_of?(Date)
        date
      when (date_string = flash[:date_of_interest]).kind_of?(String)
        Date.parse(date_string) rescue nil
      else
        nil
      end
    end

    def set_date_of_interest(date)
      flash[:date_of_interest] = date
    end

    def require_login
      unless current_user
        redirect_to sessions_new_path, flash: { error: "You need to be logged in to access this section!" }
      end
    end

    def set_device_variant
      if browser.device.mobile?
        request.variant = :mobile
      end
    end

    def current_user
      @current_user ||= if session[:user_id]
        User.find(session[:user_id])
      end
    end

    def current_business
      if session[:current_business_id] && current_user.present?
        @current_business ||= Business.joins(
            facebook_place: {managed_facebook_places: :identity}
          ).where(
            id: session[:current_business_id],
            identities: {
              user_id: current_user.id
            }
          ).first
      end
    end

    def icon_file_for(code,time_of_day)
      if code.match(/^nt_/)
        code.sub(/^nt/,'night') + '.png'
      else
        "#{time_of_day}_#{code.downcase.gsub(/\s/,'')}" + '.png'
      end
    end
end
