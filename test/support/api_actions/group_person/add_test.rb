require 'test_helper'

module ApiActions
  module GroupPerson
    class AddTest < ActiveSupport::TestCase
      def business
        @business ||= Business.create!
      end

      test 'saves all of the groups' do
        groups = [ TextGroup.new( business: business ), TextGroup.new( business: business ), TextGroup.new( business: business ) ]
        people = [ ::Person.create!, ::Person.create! ]
        ApiActions::GroupPerson::Add.new( groups, people ).call

        assert groups.all?(&:persisted?)
        groups.each do |group|
          assert_equal group.people, people
        end
      end

      test 'rolls back a transaction if there is a problem' do
        groups = [ TextGroup.new( business: business ), TextGroup.new( business: business ), TextGroup.new( business: business ) ]
        people = [ ::Person.create!, ::Person.create! ]
        groups.last.stub(:valid?, false) do
          ApiActions::GroupPerson::Add.new( groups, people ).call
        end

        assert !groups.any?(&:persisted?)
      end

    end
  end
end
