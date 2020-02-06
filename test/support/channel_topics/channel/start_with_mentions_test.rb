require 'test_helper'

module ChannelTopics
  module Channel
    class StartWithMentionsTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def around(&test)
        UpdateFuzzyWorker.stub(:perform_async, ->(*args){ UpdateFuzzyWorker.new.perform(*args) } ) do
          test.call
        end
      end

      def managers_group
        root_channel.business.text_groups.create!( name: 'gerentes', people: all_people.first(3) )
      end

      def kitchen_group
      end

      def all_people
        @all_people ||= people_names.map{|name|
          root_channel.people.create!( name: name, mobile: FFaker::PhoneNumber.short_phone_number )
        }
      end

      def people
        @people ||= all_people.map{|person| [person.name, person] }.to_h
      end

      test 'add users and groups with mentions' do
        assert_equal all_people.first(3), managers_group.people
        message = ::TextMessage.new message_text: "#chat with @gerentes @ariane @emerson : Alguém pode trabalhar hoje", message_from: people['Catarina Medeiras de Freitas'].mobile, sender: people['Catarina Medeiras de Freitas']

        topic = ChannelTopics::Channel::Start.new(message, root_channel)
        topic.call

        assert topic.started_channel.persisted?

        recipients = people.values_at(
          "Elza Sanches Delchiaro",
          "Catarina Medeiras de Freitas",
          "Sônia Vale Lópes",
          "Ariane Moura Vaz",
          "Émerson Ximenes Vaz"
        )

        assert_equal recipients.to_set, topic.recipients.to_set
        assert_equal "Alguém pode trabalhar hoje", topic.parser_message
      end

      test 'adding users with mentions and multiple line message' do
        assert_equal all_people.first(3), managers_group.people

        message_text =<<~EOM
          #chat with @gerentes @ariane @emerson
          Alguém pode trabalhar hoje, especialmente @ariane e @emerson
          Precisamos de um substituto para @DaviAzevedo e manuelamaldonado
        EOM

        message = ::TextMessage.new message_text: message_text, message_from: people['Catarina Medeiras de Freitas'].mobile, sender: people['Catarina Medeiras de Freitas']

        topic = ChannelTopics::Channel::Start.new(message, root_channel)
        topic.call

        expected_message = message_text.lines[1..-1].join("\n")

        recipients = people.values_at(
          "Elza Sanches Delchiaro",
          "Catarina Medeiras de Freitas",
          "Sônia Vale Lópes",
          "Ariane Moura Vaz",
          "Émerson Ximenes Vaz",
          "Davi Câmara de Azevedo"
        )

        assert_equal recipients.to_set, topic.recipients.to_set, "Expected sets to be the same. Instead, #{((recipients.to_set | topic.recipients.to_set) - (recipients.to_set & topic.recipients.to_set)).to_a} were not in both sets"
        assert_equal message_text.lines[1..-1].join.strip, topic.parser_message

      end

      def people_names
        <<~EON.split("\n")
          Elza Sanches Delchiaro
          Catarina Medeiras de Freitas
          Sônia Vale Lópes
          Raquel Santana Passos
          Elaine Nogueira Arruda
          Julia Hamamura Miranda
          Simone Nunes Espíndola
          Ariane Moura Vaz
          Priscila Henriques Batista
          Manuela Belchior Maldonado
          Cláudio Bonfim Neves
          Vítor Couto Hashimoto
          Douglas Falcão de Freitas
          Miguel Furtado Medeiros
          Lúcio Linhares Soares
          Conrado Freitas da Costa
          Neto Salgado Delchiaro
          Davi Câmara de Azevedo
          Émerson Ximenes Vaz
          Alessandro Amaral Serra
        EON
      end
    end
  end
end
