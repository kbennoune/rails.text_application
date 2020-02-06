class ApplicationPhoneNumberScopes
  class << self
    def available_for_business
      self.new.method('available_for_business').to_proc
    end

    def next_available_number_query
      self.new.method('next_available_number_query').to_proc
    end
  end

  attr_reader :application_phone_number_klass, :channel_klass, :channel_person_klass, :text_message_klass, :person_klass

  def initialize(application_phone_number_klass: ApplicationPhoneNumber, channel_klass: Channel, channel_person_klass: ChannelPerson, text_message_klass: TextMessage, person_klass: Person)
    @application_phone_number_klass = application_phone_number_klass
    @channel_klass = channel_klass
    @channel_person_klass = channel_person_klass
    @text_message_klass = text_message_klass
    @person_klass = person_klass
  end

  def channel_person_table
    channel_person_klass.arel_table
  end

  def channel_table
    channel_klass.arel_table
  end

  def application_phone_number_table
    application_phone_number_klass.arel_table
  end

  def text_message_table
    text_message_klass.arel_table
  end

  def person_table
    person_klass.arel_table
  end

  def permanent_channel_topics
    [::Channel::ROOM_TOPIC, ::Channel::ROOT_TOPIC]
  end

  def available_for_business(business, person)
    person_id = person.respond_to?(:id) ? person.id : person
    business_id = business.respond_to?(:id) ? business.id : business

    subquery = application_phone_number_klass.joins(:channels).where(
      channel_person_table[:person_id].eq(person_id)
    ).where(
      channel_table[:topic].in(permanent_channel_topics).and( channel_table[:business_id].not_eq(business_id) )
    ).select(:id).arel

    application_phone_number_klass.where( application_phone_number_table[:id].not_in( subquery ) )
  end

  def next_available_number_query(sunset_period, person)
    apn_cp_join = application_phone_number_table.join( channel_person_table, Arel::Nodes::OuterJoin ).on( channel_person_table[:application_phone_number_id].eq( application_phone_number_table[:id] ).and( channel_person_table[:person_id].eq(person.id) ).and( channel_person_table[:inactive].eq(false).or( channel_person_table[:inactive].eq(nil) ) ) ).join_sources
    cp_chan_node = channel_person_table.join( channel_table, Arel::Nodes::OuterJoin ).on( channel_person_table[:channel_id].eq( channel_table[:id] ) ).join_sources

    cp_tm_join = channel_person_table.join( text_message_table, Arel::Nodes::OuterJoin ).on( channel_person_table[:channel_id].eq( text_message_table[:channel_id] ) ).join_sources

    cp_p_join = channel_person_table.join( person_table, Arel::Nodes::OuterJoin ).on( channel_person_table[:person_id].eq(person_table[:id]) ).join_sources

    # This will assign an empty record if there is one available
    # because null is ordered before anything when sorting on created_at
    expiration_column = channel_person_table[:created_at]

    max_text_message_created_at_projection = Arel::Nodes::Max.new([TextMessage.arel_table[:created_at]]).as('max_text_message_created_at')
    max_channel_person_created_at_projection = Arel::Nodes::Max.new([channel_person_table[:created_at]]).as('max_channel_person_created_at')

    includes_permanent_topic_projection = Arel::Nodes::NamedFunction.new(:bit_or, [
      Arel::Nodes::InfixOperation.new(:in,
        channel_table[:topic],
        Arel::Nodes::Grouping.new(
          permanent_channel_topics.map{|topic| Arel::Nodes::Casted.new(topic, nil) }
        )
      )
    ]).as('includes_permanent_topic')

    # Concat topics is really just for debugging
    concat_topics = Arel::Nodes::NamedFunction.new(:group_concat, [channel_table[:topic]] ).as('concat_topics')

    includes_permanent_topic = Arel::Nodes::SqlLiteral.new('includes_permanent_topic')
    max_text_message_created_at = Arel::Nodes::SqlLiteral.new('max_text_message_created_at')
    max_channel_person_created_at = Arel::Nodes::SqlLiteral.new('max_channel_person_created_at')

    query = application_phone_number_klass.joins( apn_cp_join ).joins(
      cp_chan_node
    ).joins(
      cp_p_join
    ).joins(
      cp_tm_join
    ).group(
      application_phone_number_table[:id]
    ).select(
      application_phone_number_table[:*],
      max_text_message_created_at_projection,
      max_channel_person_created_at_projection,
      includes_permanent_topic_projection,
      concat_topics
    ).having(
      includes_permanent_topic.eq(0).or(includes_permanent_topic.eq(nil))
    ).having(
      max_text_message_created_at.lteq(Time.now - sunset_period).or( max_text_message_created_at.eq(nil) )
    ).having(
      max_channel_person_created_at.lteq( Time.now - sunset_period ).or(max_channel_person_created_at.eq(nil))
    ).order( max_text_message_created_at )

    query
  end
end
