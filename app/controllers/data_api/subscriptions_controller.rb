module DataApi
  class SubscriptionsController < BaseController
    skip_before_action :authorize!

    def create
      authenticator = AuthenticateSubscription.new(params[:mobile], params[:code])

      if authenticator.valid?
        builder = BuildBusinessAndPerson.new(authenticator.subscription, authenticator.mobile, params[:name], params[:business_name])

        builder.build
        person, business = builder.person, builder.business
        expiration_length = 1.month
        token = ApiRequest::JsonToken.encode(payload: {person_id: person.id}, expires_in: expiration_length)

        render json: { token: token, business_id: business.id }
      else
        render json: { errors: authenticator.errors.messages }, status: :unprocessable_entity
      end
    end


    private

      class BuildBusinessAndPerson
        attr_reader :subscription, :mobile, :name, :business_name, :errors
        def initialize(subscription, mobile, name, business_name, errors: nil)
          @subscription = subscription
          @mobile = mobile
          @name = name
          @business_name = business_name
          @errors = errors
        end

        def build
          Person.transaction do
            business.save! && person.save! && (business.admins << person)
          end
        end

        def business
          @business ||= begin
            (subscription.business || Business.new(channels: [new_root_channel], subscriptions: [subscription]) ).tap do |b|
              b.name = business_name
              b.admins
            end
          end
        end

        def person
          @person ||= begin
            Person.where( mobile: mobile ).first || Person.new( name: name, mobile: mobile )
          end
        end

        def new_root_channel
          ::Channel.new( topic: ::Channel::ROOT_TOPIC, started_by_person: person )
        end
      end
  end
end
