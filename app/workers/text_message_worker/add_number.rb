module TextMessageWorker
  class AddNumber
    attr_accessor :search_params, :application_id

    include Sidekiq::Worker

    # Search Parameters
    #
    # city	A city name.	No
    # state	A two-letter US state abbreviation ("CA" for California).	**
    # zip	A 5-digit US ZIP code.	**
    # areaCode	A 3-digit telephone area code.	**
    # localNumber	It is defined as the first digits of a telephone number inside an area code for filtering the results. It must have at least 3 digits and the areaCode field must be filled.	***
    # inLocalCallingArea	Boolean value to indicate that the search for available numbers must consider overlayed areas. Only applied for localNumber searching.	***
    # quantity	The maximum number of numbers to return (default 10, maximum 5000).	No
    # pattern	A number pattern that may include letters, digits, and the following wildcard characters:
    # - ? : matches any single digit
    # - * : matches zero or more digits
    # Don't forget to encode wildcard characters in the requested URL.

    def perform(application_id, search={})
      @search_params = search.with_indifferent_access.reverse_merge( quantity: 1 )
      @application_id = application_id

      unless [ :state, :zip, :area_code ].any?{|k| search_params.has_key?( k ) }
        raise "State, ZIP Code, or Area Code must be specified"
      end

      begin
        ApplicationPhoneNumber.create! params_for( purchased.to_data )
      rescue Exception => e
        if release_number
          raise e
        else
          logger.error("Swallowing error: #{e.inspect}\n  It will not be requeued!")
        end
      end
    end

    def release_number
      begin
        Bandwidth::PhoneNumber.delete( client, purchased[:id] )
      rescue Exception => e
        logger.error "#{purchased.inspect} couldn't be released on rollback!"
      end
    end

    def phone_number_hash
      @phone_number_hash ||= Bandwidth::AvailableNumber.search_local(client, search_params).last
    end

    def number_to_buy
      phone_number_hash[:number]
    end

    def purchased
      @purchased ||= Bandwidth::PhoneNumber.create( client, number: number_to_buy, application_id: application_id )
    end

    def params_for( purchased_params )
      purchased_params.slice(
        :name, :number, :national_number, :city, :price, :state
      ).merge(
        remote_id: purchased_params[:id],
        remote_application: purchased_params[:application],
        remote_application_id: purchased_params[:application_id],
        remote_created_at: purchased_params[:created_time],
        remote_number_state: purchased_params[:number_state],
        remote_service: 'bandwidth'
      )
    end

    def client
      @client ||= Bandwidth::Client.new Rails.application.secrets.bandwidth
    end
  end
end
