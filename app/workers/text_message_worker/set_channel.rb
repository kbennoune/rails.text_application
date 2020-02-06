module TextMessageWorker
  class SetChannel
    include Sidekiq::Worker

    attr_reader :text_message

    # Sets the channel for the message

    def perform(text_message_id)
      @text_message = TextMessage.find(text_message_id)
      assign_channel_and_sender
      queue_handler
    end

    def assign_channel_and_sender
      if text_message.channel_id.blank?
        text_message.channel = best_channel_fit
        text_message.sender_id = best_channel_fit.try(:person_id)

        text_message.save if text_message.channel_id.present?
      end
    end

    def queue_handler
      TextMessageWorker::Process.perform_async(text_message.id)
    end

    def best_channel_fit
      # If there isn't a channel then check for aliased channels
      possible_channels.first || possible_aliased_channels.first
    end

    def possible_channels
      Channel.joins(channel_people: [:person, :application_phone_number]).where(
        Person.arel_table[:mobile].eq(text_message.message_from)
      ).where(
        channel_people: {
          application_phone_numbers: { number: text_message.to }
        }
      ).order(updated_at: :desc).select(
        Channel.arel_table[:*], Person.arel_table[:mobile], Person.arel_table[:id].as('person_id')
      )
    end

    def possible_aliased_channels
      # aliased channels don't expire, meaning that if someone
      # texts in to a channel with an inactive alias, it will
      # still post to that channel

      c_table = Channel.arel_table
      cp_table = ChannelPerson.arel_table
      apn_table = ApplicationPhoneNumber.arel_table
      p_table = Person.arel_table
      pa_table = PersonAlias.arel_table
      rp_table = Person.arel_table.alias

      inner_join = Arel::Nodes::InnerJoin
      c_cp_node = c_table.join(cp_table, inner_join ).on(
        c_table[:id].eq( cp_table[:channel_id] )
      ).join_sources

      cp_apn_node = cp_table.join( apn_table, inner_join ).on(
        cp_table[:application_phone_number_id].eq(apn_table[:id])
      ).join_sources

      cp_p_node = cp_table.join( p_table, inner_join ).on(
        cp_table[:person_id].eq(p_table[:id])
      ).join_sources

      p_pa_node = p_table.join( pa_table, inner_join ).on(
        p_table[:id].eq(pa_table[:alias_id])
      ).join_sources

      pa_rp_node = pa_table.join( rp_table, inner_join ).on(
        pa_table[:real_id].eq(rp_table[:id])
      ).join_sources

      join_sources = [ c_cp_node, cp_apn_node, cp_p_node, p_pa_node, pa_rp_node ]

      Channel.joins( *join_sources ).where(
        rp_table[:mobile].eq( text_message.message_from )
      ).where(
        apn_table[:number].in( text_message.to )
      ).order(
        c_table[:updated_at].desc
      ).select(
        c_table[:*], rp_table[:mobile], rp_table[:id].as('person_id')
      )
    end
  end
end
