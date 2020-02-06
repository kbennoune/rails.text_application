module ApiActions
  module Person
    class Admission
      include ApiActions::Action
      attr_reader :inviter, :business, :admission_message

      def initialize(inviter, business)
        @inviter = inviter
        @business = business
      end

      def call(person, channels=[])
        @admission_message = new_admission_message(person)
        admission_message.save!
      end

      def message_from
        inviter.mobile
      end

      def new_admission_message(person)
        text_message_out to: person.mobile, message_from: inviter.mobile, sender: inviter, message_keys: new_admission_text, channel: root_channel, to_people: [ person.slice(:id, :mobile, :name) ]#, header_addendum_key: t('success.included_header_addendum')
      end

      def root_channel
        @root_channel ||= ::Channel.where( { business_id: business.id, topic: ::Channel::ROOT_TOPIC } ).first
      end

      def new_admission_text
        t('success', sender: inviter.display_name, business_name: business.name, included_mentions: included_mentions.join(' ') )
      end

      def included_mentions
        [ inviter, root_channel.people.where( ::Person.arel_table[:id].not_eq(inviter.id) ).first(2) ].flatten.compact.map{ |person|
          person.mention_code( within: root_channel )
        }
      end
    end
  end
end
