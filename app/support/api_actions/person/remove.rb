module ApiActions
  module Person
    class Remove
      include ApiActions::Action
      attr_reader :root_channel, :included_people, :person_ids, :person_ids, :message_from, :parent_message, :channel_business

      def initialize(root_channel, included_people, message_from, parent_message, channel_business)
        @root_channel = root_channel
        @included_people = included_people
        @person_ids = included_people.map(&:id)
        @message_from = message_from
        @parent_message = parent_message
        @channel_business = channel_business
      end

      def call
        ::Channel.transaction do
          # send a response and an error
          if included_people.present?

            ::ChannelPerson.joins(:channel).where(
              channels: { business_id: root_channel.business_id }, person_id: person_ids
            ).destroy_all

            ::TextGroupPerson.joins(:text_group).where(
              text_groups: { business_id: root_channel.business_id }, person_id: person_ids
            ).destroy_all

            successful_removed_message.save!
            @success = true
          else
            @success = false
          end
        end
      end

      def successful_removed_message
        text_message_out to: included_people.map(&:mobile), message_keys: successful_removed_text, channel: nil
      end

      def successful_removed_text
        t('success.removed', business_name: channel_business.display_name, sender: message_from.display_name )
      end

    end
  end
end
