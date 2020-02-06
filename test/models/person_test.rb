require 'test_helper'

class PersonTest < ActiveSupport::TestCase
  test "phone number gets serialized" do
    person = Person.new mobile: '(313) 565-3444'
    assert_equal person.mobile, '(313) 565-3444'
    person.save!
    db_person = Person.find(person.id)
    assert_equal db_person.mobile, '(313) 565-3444'
    assert Person.where(mobile: '(313) 565-3444').exists?
  end
end

class PersonUniquePushTest < ActiveSupport::TestCase

  def person
    @person ||= Person.create!
  end

  3.times.each do |n|
    define_method(:"channel#{n+1}"){ (@channels ||={})[ n + 1  ] ||= Channel.new business: business }
  end

  def business
    @busines ||= Business.create!
  end

  def teardown
    ChannelPerson.delete_all
    Channel.delete_all

    @channels = nil

    super
  end

  test 'channels unique_push adds records uniquely' do
    channels = [ channel1, channel2 ]

    person.channels.unique_push channels

    assert_equal person.channels.map(&:id), channels.map(&:id)

    person.channels.unique_push [ channel1, channel3 ]

    assert_equal 1, ChannelPerson.where( person: person, channel: channel1 ).count
  end

  test 'it will not save any records if there are invalid records' do
    channel3.stub(:valid?,false) do
      assert_raises(ActiveRecord::RecordInvalid){
         person.channels.unique_push([ channel1, channel2, channel3 ])
       }
    end

    assert !ChannelPerson.where( person: person, channel: [ channel1, channel2, channel3 ] ).exists?

  end

  test 'person aliases' do
    real_identity = ::Person.create! name: 'David Jones'
    bowie = ::Person.create! name: 'David Bowie'

    real_identity.aliases << bowie

    assert_equal [ real_identity ], bowie.reload.real_people
    assert_equal [ bowie ], real_identity.reload.aliases
  end

  test 'real identities at creation' do
    real_identity = ::Person.create! name: 'David Jones'
    bowie = ::Person.create! name: 'David Bowie', real_people: [ real_identity ]

    assert_equal [ real_identity ], bowie.reload.real_people
    assert_equal [ bowie ], real_identity.reload.aliases
  end

  test 'person aliases at creation' do
    bowie = ::Person.create! name: 'David Bowie'
    real_identity = ::Person.create! name: 'David Jones', aliases: [ bowie ]

    assert_equal [ real_identity ], bowie.reload.real_people
    assert_equal [ bowie ], real_identity.reload.aliases
  end
end
