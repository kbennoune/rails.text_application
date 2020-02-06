module DataApi
  class PeopleController < BaseController
    def create
      channels = [ business_root_channel ]
      text_groups = current_business.text_groups.find( params[:added_text_group_ids]).flatten.compact
      people_params = [{ mobile: params[:mobile], name: params[:name] }]
      builder = ApiActions::Person::Builder.new( current_business, people_params, groups_to_add: text_groups )
      person = builder.to_a[0]
      admission_action = ::ApiActions::Person::Admission.new( current_person, current_business )
      create_action = ::ApiActions::Person::Persist.new( person, channels, after_commit: admission_action )
      if create_action.call
        response_data = {
          people: [ create_action.person ],
          text_group_people: TextGroupPerson.joins( :text_group ).where( person: create_action.person, text_groups: { business: current_business })#create_action.person.text_group_people
        }

        render json: response_data, status: :created
      else
        render json: {}, status: :unprocessable_entity
      end
    end

    def update
      person = business_root_channel.people.find( params[:id] )
      person_params = { id: params[:id], name: params[:name], mobile: params[:mobile] }.compact
      groups_to_add = params[:added_text_group_ids].present? ? current_business.text_groups.find( params[:added_text_group_ids]).flatten.compact : []
      groups_to_remove = params[:deleted_text_group_ids].present? ? current_business.text_groups.find( params[:deleted_text_group_ids]).flatten.compact : []
      channels = [ business_root_channel ]
      builder = ::ApiActions::Person::Builder.new( current_business, [person_params], existing_people: [ person ], groups_to_add: groups_to_add, groups_to_remove: groups_to_remove )
      action = ::ApiActions::Person::Persist.new( builder.to_a.first, channels )
      if action.call
        response_data = {
          people: [ action.person ],
          text_group_people: TextGroupPerson.joins( :text_group ).where( person: action.person, text_groups: { business: current_business })#create_action.person.text_group_people

        }
        render json: response_data, status: :accepted
      else
        render json: {}, status: :unprocessable_entity
      end


    end

    def index
      businesses = Business.administered_by(current_person)

      people = business_root_channel.people.where( Person.arel_table[:updated_at].gt(last_updated_at) ).order(:updated_at)
      channels = Channel.eager_load(:people, :text_groups).where(Channel.arel_table[:updated_at].gt(last_updated_at)).where( business: current_business ).order(:updated_at).all
      text_groups = TextGroup.where(TextGroup.arel_table[:updated_at].gt(last_updated_at)).where( business: current_business ).order(:updated_at).all
      text_group_people = TextGroupPerson.where(TextGroupPerson.arel_table[:updated_at].gt(last_updated_at)).where( text_group: text_groups ).order(:updated_at).all
      last_record_updated_at = [ people.last, channels.last, text_groups.last, text_group_people.last ].compact.map(&:updated_at).max

      active_channels = Channel.active( business_id: current_business.id )
      active_channels_by_id = active_channels.map{|ac| [ac.id, ac] }.to_h

      render_data = {
        businesses: businesses,
        people: people,
        channels: channels.map{|channel| ::ChannelWrapper.new(channel, is_active: active_channels_by_id[channel.id].present? ).as_json( methods: [ :text_group_ids, :person_ids, :is_active ] )},
        text_groups: text_groups,
        text_group_people: text_group_people
      }

      if last_record_updated_at.present?
        render_data[:cache_info] = { "#{controller_name}_updated_at".to_sym => last_record_updated_at.to_i }
      end

      render json: render_data
    end

    def destroy
      remove_person = business_root_channel.people.find( params[:id] )
      action = ApiActions::Person::Remove.new( business_root_channel, [remove_person], current_person, nil, current_business)

      if action.call
        render json: { id: params[:id].to_i }, status: :accepted
      else
        render json: {}, status: :unprocessable_entity
      end
    end

    private

      def person
        @person ||= Person.joins( :channels ).where(
          people: { id: params[:id]}, channels: { business: current_business }
        ).first
      end

      def last_updated_at
        Time.at( (params[:last_updated_at] || 0).to_i )
      end

      def business_root_channel
        current_business.root_channel
      end
  end
end
