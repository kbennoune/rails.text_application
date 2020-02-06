module ApiActions
  module GroupPerson
    class Add
      attr_reader :text_groups, :included_people, :exception

      def initialize( text_groups, included_people )
        @included_people = included_people
        @text_groups = text_groups
      end

      def call
        begin
          TextGroup.transaction do
            text_groups.each do |group|
              group.people << included_people
              group.save!
            end
            @success = true
          end
        rescue ActiveRecord::RecordInvalid => exception
          @exception = exception
          @success = false
        end

        @success
      end
    end
  end
end
