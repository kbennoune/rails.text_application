require 'test_helper'

class ChannelTest < ActiveSupport::TestCase
  def channel
    @channel ||= Channel.create!( business: Business.new )
  end

  3.times.each do |n|
    define_method(:"person#{n+1}"){ (@people ||={})[ n + 1  ] ||= Person.new }
  end

  def teardown
    ChannelPerson.delete_all
    Person.delete_all

    @people = nil

    super
  end

  test 'people unique_push adds records uniquely' do
    people = [ person1, person2 ]

    channel.people.unique_push people

    assert_equal channel.people.map(&:id), people.map(&:id)

    channel.people.unique_push [ person1, person3 ]

    assert_equal 1, ChannelPerson.where( channel: channel, person: person1 ).count
  end

  test 'it will not save any records if there are invalid records' do
    person3.stub(:valid?,false) do
      assert_raises(ActiveRecord::RecordInvalid){
         channel.people.unique_push([ person1, person2, person3 ])
       }
    end

    assert !ChannelPerson.where( channel: channel, person: [ person1, person2, person3 ] ).exists?

  end
end
