require 'test_helper'

module ChannelTopics
  module Person
    class AcceptTest < ActiveSupport::TestCase
      include ChannelTopics::TestHelpers

      def root_channel
        super.tap{|c| c.business.facebook_place.update_attributes(name: 'My Business Name')}
      end

      def inviter_phone_number
        inviter.channel_people.find{|cp| cp.channel_id == root_channel.id }.channel_phone_number
      end

      def basic_invite_message
        @basic_invite_message ||= TextMessage.new(
          to: inviter_phone_number,
          message_from: inviter.mobile, sender: inviter, message_text: '#invite'
        )
      end

      def invite_groups
        @invite_groups ||= [
          TextGroup.create!( business: root_channel.business, name: 'managers'),
          TextGroup.create!( business: root_channel.business, name: 'grupo súper secreto')
        ]
      end

      def invite_message_with_groups
        @invite_message_with_groups ||= TextMessage.new(
          to: inviter_phone_number,
          message_from: inviter, message_text: "#invite to #{invite_groups.map(&:name).join(', ')}"
        )
      end

      def inviter
        @inviter ||= ::Person.create!(
          name: 'Shirley Eastman', mobile: '+2482886001'
        ).tap{|person| root_channel.people << person }
      end

      def new_user_name
        "Accepted Johnson"
      end

      def decoded_forwarded_body( instructions )
        invite_link = instructions.message_generator_keys.dig(0,'values','invite_link')
        first_decoded_body = Addressable::URI.unencode( invite_link.match(/body=(.*)/)[1])
        Addressable::URI.unencode( first_decoded_body.match(/body=(.*)/)[1])
      end

      def instructions_message_for( invite_message, channel )
        invite_action = ChannelTopics::Person::Invite.new( invite_message, channel )
        invite_action.call
        instructions = TextMessage.where( channel: channel ).where(TextMessage.arel_table[:message_generator_keys].matches( Arel::Nodes::Casted.new('%person.invite%',nil) )).last
      end

      test 'allows a user to generate an acceptable invitation through a text message' do
        instructions = instructions_message_for(basic_invite_message, root_channel)

        prepopulated_message = decoded_forwarded_body( instructions )
        acceptance_msg_text = [prepopulated_message, new_user_name].join(' ')
        acceptance_msg = TextMessage.new( message_from: '+2482881001', message_text: acceptance_msg_text )

        topic = ChannelTopics::Person::Accept.new( acceptance_msg, nil)
        topic.call

        new_person = ::Person.where( name: new_user_name ).first

        assert new_person
        assert new_person.channels.include?( root_channel )
      end

      test 'sends a welcome message to new users and a notification to the inviting user' do
        instructions = instructions_message_for(basic_invite_message, root_channel)
        prepopulated_message = decoded_forwarded_body( instructions )

        acceptance_msg_text = [prepopulated_message, new_user_name].join(' ')

        acceptance_msg = TextMessage.new( message_from: '+2482881001', message_text: acceptance_msg_text )
        topic = ChannelTopics::Person::Accept.new( acceptance_msg, nil)
        topic.call

        new_person = ::Person.where( name: new_user_name ).first

        welcome_message = TextMessage.where( TextMessage.arel_table[:message_generator_keys].matches( Arel::Nodes::Casted.new('%accept.welcome%',nil) ) ).last
        assert welcome_message
        assert_match 'Welcome', generate_text(welcome_message)
        notification_message = TextMessage.where( to: [ inviter.mobile ]).where( TextMessage.arel_table[:message_generator_keys].matches( Arel::Nodes::Casted.new('%accept.success.inviter%',nil) ) ).last
        assert notification_message
        assert_match new_user_name, generate_text( notification_message )
        assert_match 'joined', generate_text( notification_message )
      end

      test 'sends a welcome message with links to groups and the inviter' do
        existing_groups = [ 'managers', 'kitchen staff', 'everyone', 'special group' ].map{ |name|
          TextGroup.create! name: name, business: root_channel.business
        }
        instructions = instructions_message_for(basic_invite_message, root_channel)
        prepopulated_message = decoded_forwarded_body( instructions )

        acceptance_msg_text = [prepopulated_message, new_user_name].join(' ')

        acceptance_msg = TextMessage.new( message_from: '+2482881001', message_text: acceptance_msg_text )
        topic = ChannelTopics::Person::Accept.new( acceptance_msg, nil)
        topic.call

        new_person = ::Person.where( name: new_user_name ).first

        welcome_message = TextMessage.where( TextMessage.arel_table[:message_generator_keys].matches( Arel::Nodes::Casted.new('%accept.welcome%',nil) ) ).last
        root_number = welcome_message.to.first
        text_message = generate_text( welcome_message, root_number: root_number )

        existing_groups.each do |group|
          encoded_group = group.name.gsub(/\s/,'')
          assert_match encoded_group, text_message
          assert_match "sms:#{root_number.to_s(:url)}?body=@#{encoded_group}", text_message
        end

        assert_match "sms:#{root_number.to_s(:url)}?body=@#{inviter.name.downcase.gsub(' ','')}", text_message
      end

      test 'sends a contact file with the welcome message' do
        invite_action = ChannelTopics::Person::Invite.new( basic_invite_message, root_channel )
        invite_action.call

        forwardable_invite = TextMessage.where( channel: root_channel ).where(TextMessage.arel_table[:message_generator_keys].matches( Arel::Nodes::Casted.new('%person.invite%',nil) )).last
        acceptance_msg_text = generate_text(forwardable_invite) + "\n@#{new_user_name}"
        acceptance_msg = TextMessage.new( message_from: '+2482881001', message_text: acceptance_msg_text )

        topic = ChannelTopics::Person::Accept.new( acceptance_msg, nil)
        topic.call

        new_person = ::Person.where( name: new_user_name ).first

        welcome_message = TextMessage.where( TextMessage.arel_table[:message_generator_keys].matches( Arel::Nodes::Casted.new('%accept.welcome%',nil) ) ).last
        assert welcome_message.message_media.grep(/\/contacts\/#{root_channel.business_id}\/#{new_person.id}\/app/).present?
        assert welcome_message.message_media.grep( Regexp.new('http://test.text_application.com') ).present?

      end

      test 'allows a user to just send a code to the root phone number' do
        invite_action = ChannelTopics::Person::Invite.new( basic_invite_message, root_channel )
        invite_action.call

        instructions_msg = TextMessage.where( channel: root_channel ).where( TextMessage.arel_table[:message_generator_keys].matches( Arel::Nodes::Casted.new('%invite.instructions%',nil) ) ).last
        code = generate_text(instructions_msg).match(/.*(!inv-[a-z]{4,10}-[a-z]{4,10})/)[1]
        phone_number = generate_text(instructions_msg).match(/[\s\(\)\d-]{4,}/).to_s.strip

        message_text =<<~EOM
          #{code}
          @ #{new_user_name}
        EOM
        acceptance_msg = TextMessage.new( message_from: phone_number, message_text: message_text )

        topic = ChannelTopics::Person::Accept.new( acceptance_msg, nil)
        topic.call

        new_person = ::Person.where( name: new_user_name ).first

        assert new_person
        assert new_person.channels.include?( root_channel )
      end

      test 'adds a user to the groups that were used generating the invite code' do
        instructions = instructions_message_for(invite_message_with_groups, root_channel)
        prepopulated_message = decoded_forwarded_body( instructions )

        acceptance_msg_text = [prepopulated_message, new_user_name].join(' ')

        acceptance_msg = TextMessage.new( message_from: '+2482881001', message_text: acceptance_msg_text )

        topic = ChannelTopics::Person::Accept.new( acceptance_msg, nil)
        topic.call

        new_person = ::Person.where( name: new_user_name ).first

        assert new_person
        assert new_person.channels.include?( root_channel )

        invite_groups.each do |group|
          assert group.people.include?(new_person)
        end
      end

      test 'adds a user to the channel groups that were used generating the invite' do
        managers_group_channel = ::Channel.create! business: business, topic: ::Channel::ROOM_TOPIC, channel_groups: [ChannelGroup.new( text_group: invite_groups[0] )]

        instructions = instructions_message_for(invite_message_with_groups, root_channel)
        prepopulated_message = decoded_forwarded_body( instructions )

        acceptance_msg_text = [prepopulated_message, new_user_name].join(' ')

        acceptance_msg = TextMessage.new( message_from: '+2482881001', message_text: acceptance_msg_text )

        topic = ChannelTopics::Person::Accept.new( acceptance_msg, nil)
        topic.call

        new_person = ::Person.where( name: new_user_name ).first

        assert new_person
        assert new_person.channels.include?( root_channel )

        assert new_person.channels.include?( managers_group_channel )
      end

      test 'it generates a message' do
        managers_group_channel = ::Channel.create! business: business, topic: ::Channel::ROOM_TOPIC, channel_groups: [ChannelGroup.new( text_group: invite_groups[0] )]

        instructions = instructions_message_for(invite_message_with_groups, root_channel)
        prepopulated_message = decoded_forwarded_body( instructions )

        acceptance_msg_text = [prepopulated_message, new_user_name].join(' ')

        acceptance_msg = TextMessage.new( message_from: '+2482881001', message_text: acceptance_msg_text )

        topic = ChannelTopics::Person::Accept.new( acceptance_msg, nil)
        topic.call

        text_message = topic.welcome_message
        new_person = topic.person
        invitation = topic.invitation

        text = TextMessageWorker::Send.new.message_text_for( new_person.channel_people.find{|cp| cp.channel.topic == ::Channel::ROOT_TOPIC }, text_message )
        puts text
        assert_match 'CHAT', text
        assert_equal 1, text.scan('Managers').size
        assert_equal 1, text.scan('Grupo Súper Secreto').size
      end
    end
  end
end
