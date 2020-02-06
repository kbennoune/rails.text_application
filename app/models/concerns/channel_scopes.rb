class ChannelScopes
  class << self
    def active
      self.new.method('active').to_proc
    end

    def matching_active
      self.new.method('matching_active').to_proc
    end
  end

  attr_reader :channel_klass, :channel_person_klass, :channel_group_klass, :person_klass

  def initialize(channel_klass: Channel, channel_person_klass: ChannelPerson, channel_group_klass: ChannelGroup, person_klass: Person)
    @channel_klass = channel_klass
    @channel_person_klass = channel_person_klass
    @channel_group_klass = channel_group_klass
    @person_klass = person_klass
  end

  def root_topic
    ::Channel::ROOT_TOPIC
  end

  def channel_table
    channel_klass.arel_table
  end

  def channel_person_table
    channel_person_klass.arel_table
  end

  def channel_group_table
    channel_group_klass.arel_table
  end

  def person_table
    person_klass.arel_table
  end

  # matching_active will find a channel with the same text group and people
  # recipients. It's initial use is to find existing channels when starting
  # a channel from a list of people and text groups.
  # NOTE: The business id check is only true if all the users are in the
  # root channel. Otherwise it will skip anyone who isn't in the root.
  def matching_active(business_id, people_ids = [], text_group_ids = [], topic: 'chat')

    base_query = active(business_id: business_id)
    cp_table = channel_person_table.alias('channel_people_matching_active_1')
    cg_table = channel_group_table.alias('channel_groups_matching_active_1')
    cp_join = channel_table.join(cp_table).on( channel_table[:id].eq(cp_table[:channel_id]) )
    cg_join = channel_table.join(cg_table).on( channel_table[:id].eq(cg_table[:channel_id]) )

    cp_table2 = channel_person_table.alias('channel_people_matching_active_2')
    cg_table2 = channel_group_table.alias('channel_groups_matching_active_2')

    cp_join2 = channel_table.join(cp_table2).on( channel_table[:id].eq(cp_table2[:channel_id]) )
    cg_join2 = channel_table.join(cg_table2).on( channel_table[:id].eq(cg_table2[:channel_id]) )

    person_count = Arel::Nodes::Count.new([cp_table[:person_id]], true)
    text_group_count = Arel::Nodes::Count.new([cg_table[:text_group_id]], true)

    person_count = Arel::Nodes::Count.new([cp_table[:person_id]], true)
    text_group_count = Arel::Nodes::Count.new([cg_table[:text_group_id]], true)

    person_count2 = Arel::Nodes::Count.new([cp_table2[:person_id]], true)
    text_group_count2 = Arel::Nodes::Count.new([cg_table2[:text_group_id]], true)

    built_query = base_query.joins(
      cp_join.join_sources
    ).joins(
      cp_join2.join_sources
    ).where(
      cp_table[:person_id].in(people_ids)
    )

    if text_group_ids.present?
      built_query = built_query.joins(
        cg_join.join_sources
      ).joins(
        cg_join2.join_sources
      )
    end

    built_query = if text_group_ids.present?
      built_query.having(
        person_count.eq(people_ids.length).and(text_group_count.eq(text_group_ids.length))
      ).having(
        person_count.eq(person_count2).and(text_group_count.eq(text_group_count2))
      )
    else
      built_query.having(
        person_count.eq(people_ids.length)
      ).having(
        person_count.eq(person_count2)
      )
    end

    if text_group_ids.present?
      built_query = built_query.where( cg_table[:text_group_id].in(text_group_ids) )
    end

    if topic.present? && topic.kind_of?(Array)
      built_query =  built_query.where( channel_table[:topic].in(topic) )
    elsif topic.present?
      built_query = built_query.where( channel_table[:topic].eq(topic) )
    end

    built_query
  end

  def latest_by_person_and_number(business_id, aliased_channel_person_table=channel_person_table.alias('aliased_channel_person_table'), subquery_channel_people=channel_person_table.alias('subquery_channel_people'))
    self_join = channel_person_table.join( aliased_channel_person_table ).on(
      subquery_channel_people[:application_phone_number_id].eq(
        aliased_channel_person_table[:application_phone_number_id]
      ).and(
        subquery_channel_people[:person_id].eq(aliased_channel_person_table[:person_id])
      )
    ).join_sources

    active_channel_calculation = Arel::Nodes::Max.new([subquery_channel_people[:channel_id]]).as('active_channel_id')

    base_subquery = channel_person_klass.joins(self_join).group(
      subquery_channel_people[:person_id], subquery_channel_people[:application_phone_number_id]
    ).select(
      active_channel_calculation,
      subquery_channel_people[:person_id],
      subquery_channel_people[:application_phone_number_id]
    ).from(subquery_channel_people).order(
      'active_channel_id'
    )

    if business_id.present?
      p_table = person_table.alias('p_table')
      c_table = channel_table.alias('c_table')
      cp_table = channel_person_table.alias('cp_table')

      pc_p_c_join = channel_person_table.join(p_table).on(subquery_channel_people[:person_id].eq(p_table[:id])).join( cp_table, Arel::Nodes::InnerJoin
      ).on(
        p_table[:id].eq(cp_table[:person_id])
      ).join(
        c_table
      ).on(
        c_table[:id].eq(cp_table[:channel_id])
      )

      base_subquery = base_subquery.joins(
        pc_p_c_join.join_sources
      )

      if business_id.present?
        base_subquery = base_subquery.where(
          c_table[:topic].eq(root_topic).and(c_table[:business_id].eq(business_id))
        )
      end
    end

    return base_subquery
  end

  def wrapped_join_for_active(subquery, original_channel_person, additional_channel_person)
    join = channel_table.join(subquery)
    join.on(subquery[:active_channel_id].eq(channel_table[:id]))

    join.project(channel_table[:*])

    join.join( original_channel_person ).on( original_channel_person[:channel_id].eq(channel_table[:id]).and(original_channel_person[:person_id].eq(subquery[:person_id]) ))

    join.join(additional_channel_person).on( additional_channel_person[:channel_id].eq( channel_table[:id] ) )
    join
  end

  def wrapped_query_for_active(subquery, original_channel_person=channel_person_table.alias('original_channel_person'), additional_channel_person=channel_person_table.alias('another_alias'))
    total_people = Arel::Nodes::Count.new([additional_channel_person[:person_id]], true, 'total_people')
    active_people = Arel::Nodes::Count.new([subquery[:person_id]], true, 'active_people')

    join = wrapped_join_for_active(subquery, original_channel_person, additional_channel_person )

    final_query = channel_klass.joins( join.join_sources ).group(
      additional_channel_person[:channel_id]
     ).group(
       original_channel_person[:channel_id]
     ).select(
       channel_table[:*], total_people, active_people
     ).having(
       total_people.alias.eq(active_people.alias)
     )

     final_query
  end

  # active finds all of the channels that are currently
  # receiving text messages for all people
  def active(business_id: nil)
    subquery_joined_channel_people = channel_person_table


    subquery = latest_by_person_and_number(business_id).as(
      Arel.sql('subquery_alias')
    )

    final_query = wrapped_query_for_active(subquery)

    if business_id
      final_query = final_query.where( channel_table[:business_id].eq(business_id) )
    end

    final_query
  end

end
