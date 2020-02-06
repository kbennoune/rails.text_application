module ChannelTopics
  module Person
    class Create < ChannelTopics::Processor
      include ::ChannelTopics::ContactInfoHelper

      def call
        if person.present?
          call_create_action!

          success_response_message.save!
        else
          failed_response_message.save!
        end
      end

      def call_create_action!
        ::Person.transaction do
          action.call
          if action.exception.present?
            raise action.exception
          end

          true
        end
      end

      def action
        @action ||= ApiActions::Person::Persist.new( person, [ channel ] )
      end

      def failed_response_message
        @failed_response_message ||= text_message_out to: :sender, message_keys: failed_response_text
      end

      def failed_response_text
        t("failed.#{contact_file.present? ? 'contact_file' : 'text' }", support_number: support_number.formatted )
      end

      def success_response_message
        @success_response_message ||= text_message_out to: :sender, message_keys: success_response_text
      end

      def success_response_text
        groups = person.text_group_people.find_all(&:id_previously_changed?).map(&:text_group_name)
        key = ['success',  groups.present? ? 'with_groups' : 'base'].join('.')

        t(key, groups: groups, person: person.display_name)
      end

      def call_inverse
        # remove person from channel
        if inverse_is_delete?
          # person.
        end
      end

      def inverse_is_delete?
        updated_at = person.updated_at
        created_at = person.created_at
        threshold_time = Time.now + 2.hours
        created_at == updated_at && created_at > threshold_time
      end

      def person
        @person ||= if person_attributes.present?
          existing_or_new_person(person_attributes).tap{|p| p.attributes = subbing_relations( person_attributes ) }
        end
      end

      def person_attributes
        @person_attributes ||= begin
          message_attributes = if message_text.present?
            contact_info_from_text
          else
            {}
          end

          contact_file_attributes = if contact_file.vcard?
            contact_file.person_data
          else
            {}
          end

          message_attributes.merge( contact_file_attributes )
        end
      end

      def subbing_relations(attrs)
        if group_names = attrs.delete(:group_names)
          (attrs[:text_groups] ||= []).push( *text_groups_for(group_names) )
        end

        attrs
      end

      def text_groups_for(group_names=[])
        existing_groups = TextGroup.where( business_id: channel.business_id, name: group_names)
        group_names.map do |name|
          existing_groups.find{|existing| existing.name == name } || ::TextGroup.new( name: name, business_id: channel.business_id, created_by_person: message_sender )
        end
      end

      def existing_or_new_person(attributes)
        ::Person.where(mobile: attributes[:mobile] ).first ||
        ::Person.where(name: attributes[:name] ).first ||
         ::Person.new
      end

      def contact_file
        @contact_file ||= if (url = message.message_media.find{|url| url.match(/\.(vcf|vcard)$/)})
          files = Bandwidth::Media.download( client, url.split('/').last )
          ContactFile.new(files[0])
        else
          ContactFile.new
        end
      end

      def client
        @client ||= Bandwidth::Client.new Rails.application.secrets.bandwidth
      end
    end
  end
end
