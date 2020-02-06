module ApiActions
  module Person
    class Persist
      include ApiActions::Action
      attr_reader :person, :channels, :exception
      attr_reader :after_commit, :after_rollback

      def initialize( person, channels, after_commit: nil, after_rollback: nil )
        @person = person
        @channels = channels
        @after_commit = after_commit
        @after_rollback = after_rollback
      end

      def call
        begin
          ::Person.transaction do
            person.save!
            channels.each do |channel|
              person.channels.unique_push channel
            end

            @success = true
          end
        rescue ActiveRecord::RecordInvalid => exception
          @exception = exception
          @success = false
        end

        run_callbacks

        @success
      end

      private

        def run_callbacks
          if @success && after_commit.respond_to?(:call)
            after_commit.call(person, channels)
          end

          if !@success && after_rollback.respond_to?(:call)
            after_rollback.call(exception, person, channels)
          end
        end
    end
  end
end
