module BreadcrumbCalculator
  def self.included( controller )
    controller.helper_method(:linked_from_url)
  end

  delegate :linked_from_url, :parent_page_path, to: :breadcrumb_params_calculator

  def breadcrumb_params_calculator
    @breadcrumb_params_calculator ||= ParamsCalculator.new( params, request.referer )
  end

  class ParamsCalculator
    attr_reader :params, :default_fallback_path
    delegate :url_for, to: :'Rails.application.routes.url_helpers'

    def initialize(params, referer_url, default_fallback_path: { action: 'show', controller: 'monthly_calendars' })
      @params = params
      @referer_url = referer_url
      @default_fallback_path = default_fallback_path
    end

    def referer
      @referer ||= if @referer_url.present?
        Addressable::URI.parse( @referer_url )
      end
    end

    def parent_page_path(fallback: default_fallback_path, url: nil)
      path = path_for_url( url || params[:redirect_on_save] )

      if path[:controller] == params[:controller]
        fallback
      else
        path
      end

    end

    def linked_from_url
      params[:redirect_on_save] || linked_from_url_from_referer
    end

    private

      def linked_from_url_from_referer
        if referer
          url_for( path_for_url( referer.path ).merge(only_path: true) )
        end
      end

      def path_for_url(url, fallback_path=default_fallback_path)
        if url.present?
          begin
            Rails.application.routes.recognize_path(url)
          rescue ActionController::RoutingError, NoMethodError
            fallback_path
          end
        else
          fallback_path
        end
      end
  end

end
