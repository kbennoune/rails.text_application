require 'test_helper'

class TrigramTest < ActiveSupport::TestCase
  include ChannelTopics::TestHelpers

  def people
    [ channel_people, other_people ].flatten
  end

  def channel_people
    @channel_people ||= root_channel.people.create!(
      channel_people_names.map{|name| { name: name } }
    )
  end

  def other_people
    @other_people ||= Person.create!(
      other_people_names.map{|name| { name: name } },
    )
  end

  def groups
    @groups ||= [
      group_names[0..2].map{|name| root_channel.business.text_groups.create!(name: name) },
      group_names[3..-1].map{|name| TextGroup.create!( name: name, business: Business.new ) }
    ].flatten
  end

  def setup
    super

    Sidekiq::Testing.inline!
  end

  def teardown
    Sidekiq::Testing.fake!
    super
  end

  test 'finding trigrams by people names' do
    person = people.find{|person| person.name == 'Santino Barrios' }
    assert_equal person.id, Trigram.matches_for('SantinoB').first.owner_id
  end

  test 'finding trigrams scoped by channel' do
    person = people.find{|person| person.name == 'Mateo Amengual' }
    assert_equal person.id, Trigram.channel_matches_for(root_channel, 'MateoB').first.owner_id
  end

  test 'finding short people trigrams' do
    people
    person = Person.create! name: 'Tj', channels: [ root_channel ]

    assert person != Trigram.channel_matches_for(root_channel, 'broken').first.owner
  end

  test 'finding short group trigrams' do
    groups
    group = TextGroup.create! name: 'ab', business: root_channel.business
    assert group != Trigram.channel_matches_for(root_channel, 'broken').first.owner
  end

  test 'finding groups scoped by channel' do
    people
    group = groups.find{|group| group.name == 'gerentes'}
    assert_equal group.id, Trigram.channel_matches_for(root_channel, 'gerentes').first.owner_id
    group = groups.find{|group| group.name == 'todos en el restaurante'}
    assert_equal group.id, Trigram.channel_matches_for(root_channel, 'todos').first.owner_id
  end

  test 'ties go to groups' do
    group = groups.find{|group| group.name == 'todos en el restaurante'}
    new_person = root_channel.people.create!( name: 'todos en el restaurante')
    assert_equal group.id, Trigram.channel_matches_for(root_channel, 'todosenelrestaurante').first.owner_id
  end

  test 'ties between people go to the person added to the root channel earlier' do
    person2 = Person.create!(name: 'Jon Smith')
    person1 = Person.create!(name: 'Jon Smith')

    person1.channels << root_channel
    person2.channels << root_channel

    assert_equal person1.id, Trigram.channel_matches_for(root_channel, 'johnsmith').first.owner_id
  end

  def channel_people_names
    <<~EONAMES.split("\n")
      Mateo Amengual
      Santino Barrios
      Bautista Espinar
      Felipe Venegas
      Alfonso Saavedra
      Franco Agramonte
      Cristóbal Cortés
      Víctor Montenegro
      Alberto Villa
      Héctor Sánchez
    EONAMES
  end

  def other_people_names
    <<~EONAMES.split("\n")
      Mateo Botín
      Jeremías Franco
      Rafael Varela
      Joshua Gálvez
      Alfredo Cambeiro
      Joaquín Indiano
      Jesús Garrido
      Thiago Luque
      Alfredo Cazalla
      Bautista Casaus
    EONAMES
  end

  def group_names
    <<~EONAMES.split("\n")
      todos en el restaurante
      gerentes
      cocineros
      camarera
      limpiadores
      todos
    EONAMES
  end
end
