module DataApi
  class MessagesController < BaseController
    def create
      if action.call
        channels = [ ChannelWrapper.new(action.channel, is_active: true).as_json( methods: [ :text_group_ids, :person_ids, :is_active ] ) ]
        messages = [ TextMessageWrapper.new( action.messages.last, current_person ).as_json( methods: :message_text ) ]
        response = { channels:  channels, messages: messages }
        render json: response
      else
        errors = {}
        render json: errors, status: :unprocessable_entity
      end
    end

    private
      def action
        @action ||= if params[:channel_id]
          channel = current_person.channels.find( params[:channel_id] )
          ::ApiActions::Message::Send.new( channel, message_text, current_person, current_person )
        else
          ::ApiActions::Channel::Start.new( current_person, current_person.mobile, included_recipients, channel_for_message, message_text )
        end
      end

      def included_recipients
        [people_recipients, text_group_recipients].flatten.uniq.compact
      end

      def channel_for_message
        ChannelForRecipients.new(
          ::Channel::CHAT_TOPIC,
          sender: current_person, business_id: current_business.id,
          started_by: current_person, text_groups: text_groups,
          receivers: [ included_recipients, current_person ].flatten.compact
        ).channel
      end

      def message_text
        params[ :message_text ]
      end

      def text_group_recipients
        text_groups.map(&:people).flatten
      end

      def text_groups
        @text_groups ||= if params[:text_group_ids].present?
          TextGroup.where( business: current_business ).find( params[:text_group_ids] )
        else
          []
        end
      end

      def people_recipients
        current_business.root_channel.people.find( params[:people_ids] )
      end

  end
end
