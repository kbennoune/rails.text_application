module RailsAdmin
  module Config
    module Actions
      class Impersonate < RailsAdmin::Config::Actions::Base
        register_instance_option :visible? do
          bindings[:object].kind_of?(User)
        end

        register_instance_option :member? do
          true
        end

        register_instance_option :pjax? do
          false
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :link_icon do
          'icon-home'
        end

        register_instance_option :controller do
          Proc.new do
            session[:admin_user_id] = session[:user_id]
            session[:user_id] = @object.id
            redirect_to "/"
          end
        end

        RailsAdmin::Config::Actions.register(self)
      end
    end
  end
end

RailsAdmin.config do |config|

  ### Popular gems integration

  ## == Devise ==
  # config.authenticate_with do
  #   warden.authenticate! scope: :user
  # end
  # config.current_user_method(&:current_user)

  ## == Cancan ==
  # config.authorize_with :cancan

  ## == Pundit ==
  # config.authorize_with :pundit

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  ### More at https://github.com/sferik/rails_admin/wiki/Base-configuration

  ## == Gravatar integration ==
  ## To disable Gravatar integration in Navigation Bar set to false
  # config.show_gravatar = true
  config.main_app_name = ["TextApplication", "BackOffice"]

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new
    export
    bulk_delete
    show
    edit
    delete
    show_in_app

    impersonate
    ## With an audit adapter, you can add:
    # history_index
    # history_show
  end
end
