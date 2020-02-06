module ApiActions
  module GroupPerson
    class Remove
      attr_reader :text_groups, :people, :exception

      def initialize( text_groups, people )
        @people = people
        @text_groups = text_groups
      end

      def call
        begin
          TextGroup.transaction do
            text_groups.each do |group|
              group.people.destroy( people )
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
