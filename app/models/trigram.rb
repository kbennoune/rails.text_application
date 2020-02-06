class Trigram < ActiveRecord::Base
  include Fuzzily::Model

  scope :channel_matches_for, ->(channel, name, query_type: :left_join){
    p_tbl = Person.arel_table
    cp_tbl = ChannelPerson.arel_table
    g_tbl = TextGroup.arel_table
    b_tbl = Business.arel_table
    c_tbl = Channel.arel_table

    tbl = self.arel_table

    node_type = { left_join: Arel::Nodes::OuterJoin, union: Arel::Nodes::InnerJoin }[ query_type ]

    person_join_node = tbl.join( p_tbl, node_type ).on(
      tbl[:owner_id].eq(p_tbl[:id]).and(tbl[:owner_type].eq('Person'))
    ).join_sources

    channel_person_join_node = p_tbl.join( cp_tbl, node_type ).on(
      p_tbl[:id].eq(cp_tbl[:person_id])
    ).join_sources

    channel_business_join_node = b_tbl.join( c_tbl, node_type ).on(
      b_tbl[:id].eq( c_tbl[:business_id] )
    ).join_sources


    group_join_node = tbl.join( g_tbl, node_type ).on(
      tbl[:owner_id].eq(g_tbl[:id]).and(tbl[:owner_type].eq('TextGroup'))
    ).join_sources


    business_group_join_node = g_tbl.join( b_tbl, node_type ).on(
      g_tbl[:business_id].eq(b_tbl[:id])
    ).join_sources


    if query_type == :union

      first_query = select(cp_tbl[:id].as('id_for_order')).joins( person_join_node ).joins( channel_person_join_node ).where( cp_tbl[:channel_id].eq(channel.id) ).
                      matches_for(name).reorder(nil).group(cp_tbl[:id])

      second_query = select('null as id_for_order').joins(group_join_node).joins(business_group_join_node).joins(channel_business_join_node).
                       where( c_tbl[:id].eq( channel.id )  ).
                       matches_for(name).reorder(nil)

      Trigram.from( Trigram.arel_table.create_table_alias(  first_query.union(second_query), :trigrams ) ).order(matches: :desc, score: :asc, owner_type: :desc, id_for_order: :asc)

    else
      joins( person_join_node ).joins( channel_person_join_node ).
        joins( group_join_node ).joins( business_group_join_node ).joins( channel_business_join_node ).
        where((cp_tbl[:channel_id].eq(channel.id).and(cp_tbl[:person_id].eq(p_tbl[:id]))).or(c_tbl[:id].eq(channel.id))).
        matches_for(name).order(owner_type: :desc).order( cp_tbl[:id].asc ).group(cp_tbl[:id])
    end

  }


  def self.matching_group_or_person(name)
    match = channel_matches_for( name ).first

    match.try(:owner)
  end
end
