module DataApi
  class ChannelsController < BaseController
    PRIVATE_MESSAGE_KEYS = [
      'channel_topics.authentication_message.send.',
      'channel_topics.authentication_message.send'
    ]

    def index
      channels = Channel.eager_load(:people, :text_groups, :channel_groups).where(Channel.arel_table[:updated_at].gt(last_updated_at)).where( business: current_business ).all
      messages = TextMessage.includes(:channel, :sender, :original_sender).where(TextMessage.arel_table[:message_generator_key].not_in(PRIVATE_MESSAGE_KEYS)).where(TextMessage.arel_table[:updated_at].gt(last_updated_at)).where( channel: channels ).all
      permanent_channel_groups = ChannelGroup.joins(:channel).where(ChannelGroup.arel_table[:updated_at].gt(last_updated_at)).where( channel: channels, channels: { topic: ::Channel::ROOM_TOPIC } ).all

      last_record_updated_at = [ channels.last, messages.last, permanent_channel_groups.last ].compact.map(&:updated_at).max

      active_channels = Channel.active( business_id: current_business.id )
      active_channels_by_id = active_channels.map{|ac| [ac.id, ac] }.to_h

      data = {
        permanent_channel_groups: permanent_channel_groups.map(&:as_json),
        channels: channels.map{|channel| ChannelWrapper.new(channel, is_active: active_channels_by_id[channel.id].present?).as_json( methods: [ :text_group_ids, :person_ids, :is_active ] )},
        messages: messages.map{|message| TextMessageWrapper.new( message, current_person ).as_json( methods: [:sender_id, :message_text] ) }
      }

      if last_record_updated_at.present?
        data[:cache_info] = { channels_updated_at: last_record_updated_at.to_i }
      end

      render json: data
    end

    def get
      channel = Channel.eager_load(:people, :text_groups, :channel_groups).where( business: current_business ).find( params[:id] )

      data = { messages: messages }

      if channel.updated_at > last_updated_at
        data[:channels] = [ channel.as_json( methods: [ :text_group_ids, :person_ids ] ) ]
      end

      if last_record_updated_at.present?
        data[:cache_info] = { channel_updated_ats: { params[:id] => last_record_updated_at.to_i } }
      end

      render json: data
    end

    private

    def last_updated_at
      Time.at( (params[:last_updated_at] || 0).to_i )
    end
  end
end
