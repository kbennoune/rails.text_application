module TextChannelWorker
  class Create
    include Sidekiq::Worker
    attr_reader :business, :text_group

    def perform( business_id, text_group_id )
      @business = Business.find( business_id )

      @text_group = @business.text_groups.find( text_group_id )

      create_group_channel
    end

    def create_group_channel
      Channel.create_group_channel( business, text_group )
    end
  end
end
