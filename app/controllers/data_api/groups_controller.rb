module DataApi
  class GroupsController < BaseController

    def create
      text_group = TextGroup.new( business: current_business, name: params[:name] )
      # Don't set set_permanent to false when creating
      set_permanent = params[:set_permanent] || nil
      PermanentChannelSetter.new( text_group, current_person, set_permanent ).mutate

      action = ::ApiActions::GroupPerson::Add.new( [ text_group ], added_people )

      if action.call
        response_data = {
          text_groups: action.text_groups,
          text_group_people: action.text_groups.map(&:text_group_people).flatten,
          permanent_channel_groups: text_group.permanent_channel_groups,
          channels: text_group.channels.map{|channel| channel.as_json( methods: [ :text_group_ids, :person_ids ] )}
        }
        render json: response_data, status: :created
      else
        render json: {}, status: :unprocessable_entity
      end
    end

    class PermanentChannelSetter
      attr_reader :has_permanent_channel, :text_group, :started_by

      def initialize( text_group, started_by, has_permanent_channel)
        @text_group = text_group
        @has_permanent_channel = has_permanent_channel
        @started_by = started_by
      end

      def mutate
        return true if has_permanent_channel.nil?

        if has_permanent_channel
          return true if text_group.permanent_channels.present?

          Channel.build_group_channel( text_group.business, text_group, started_by: started_by )
        else
          text_group.permanent_channels.each(&:mark_for_destruction)
        end
      end
    end

    def update
      text_group = current_business.text_groups.find( params[:id] )
      results = nil
      add_action = ::ApiActions::GroupPerson::Add.new( [ text_group ], added_people )
      remove_action = ::ApiActions::GroupPerson::Remove.new( [ text_group ], removed_people )

      # set_permanent_channel
      # Needs to create a room channel if set to true
      # Needs to convert all permanent channels to CHAT_TOPIC if false
      # Does nothing if nil...

      TextGroup.transaction do
        if params[:name].present?
          text_group.name = params[:name]
        end

        PermanentChannelSetter.new( text_group, current_person, params[:set_permanent] ).mutate

        results = add_action.call && remove_action.call

        raise ActiveRecord::Rollback unless results
      end

      if results
        response_data = {
          text_groups: [ text_group ],
          text_group_people: remove_action.text_groups.map(&:text_group_people).flatten,
          permanent_channel_groups: text_group.reload.permanent_channel_groups,
          channels: text_group.channels.map{|channel| channel.as_json( methods: [ :text_group_ids, :person_ids ] )}
         }

        render json: response_data, status: :accepted
      else
        render json: {}, status: :unprocessable_entity
      end
    end

    def destroy
      text_group = current_business.text_groups.find( params[:id] )

      if text_group.destroy
        render json: { id: text_group.id }, status: :accepted
      else
        render json: {}, status: :unprocessable_entity
      end
    end

    private

      def added_people
        @added_people ||= current_business.root_channel.people.find( params[:added_contact_ids] )
      end

      def removed_people
        @removed_people ||= current_business.root_channel.people.find( params[:deleted_contact_ids] )
      end
  end
end
