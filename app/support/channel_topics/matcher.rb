module ChannelTopics
  class Matcher
    attr_reader :message, :channel
    # If the message includes a contact then it should be
    # a person add unless it's a remove, if it's to the
    # main channel it should be a

    class << self
      def topic(message, channel)
        new(message, channel).topic
      end
    end

    def initialize( message, channel )
      @message = message
      @channel = channel
    end

    def topic
      string_router.route(self, message.message_text) do |topic_klass, route|
        topic_klass.new( message, channel, route )
      end
    end

    def string_router
      StringRouter.new do
        match /#chat/i, to: ChannelTopics::Channel::Start
        match /#help/i, to: ChannelTopics::Channel::Help
        match /#list.* groups/i, to: ChannelTopics::Group::List
        match /#list\s+all\s*/i, to: ChannelTopics::Participant::List
        match /#list\s*\S+/i, to: ChannelTopics::GroupPerson::List
        match /#list/i, to: ChannelTopics::Participant::List
        match /#leave/i, to: ChannelTopics::GroupPerson::Leave
        match /^\s*#contact/i, to: ChannelTopics::Channel::ListFile

        match /#[Ee]spa[nñ]ol/i, to: ChannelTopics::Person::SetLanguage
        match /#[Ee]nglish/i, to: ChannelTopics::Person::SetLanguage

        scope channel: { topic: ::Channel::ROOT_TOPIC } do
          match /^\s*#add.*\sto\s/i, to: ChannelTopics::GroupPerson::Add
          match /remove/i, message: { message_media: /\.(vcf|vcard)$/ }, to: ChannelTopics::Person::Remove
          match /^\s*#remove.*\sfrom\s/i, to: ChannelTopics::GroupPerson::Remove
          match /^\s*#erase.+/i, to: ChannelTopics::Person::Remove
          match /.*/, message: { message_media: /\.(vcf|vcard)$/ }, to: ChannelTopics::Person::Create
          match /^\s*#invite.*\d{3,}/i, to: ChannelTopics::Person::Add
          match /^\s*#invite/i, to: ChannelTopics::Person::Invite
          match /^\s*#poll/i, to: ChannelTopics::Poll::Start
          match /^\s*#set\s/i, to: ChannelTopics::Alias::Set
        end

        scope channel: { topic: ::Channel::CHAT_TOPIC } do
          match /#remove/i, to: ChannelTopics::Participant::Remove
          match /#add/i, to: ChannelTopics::Participant::Add
          match /#stop/i, to: ChannelTopics::Participant::RemoveSelf
        end

        scope channel: { topic: ::Channel::POLL_TOPIC } do
          match /#remove/i, to: ChannelTopics::Participant::Remove
          match /#add/i, to: ChannelTopics::Participant::Add
        end

        scope channel: { nil?: true } do
          match /inv-\S{4,8}-[a-z]{4,8}/, to: ChannelTopics::Person::Accept
        end

        match /inv-\S{4,8}-[a-z]{4,8}/, to: ChannelTopics::Person::Accept

        scope channel: { topic: ::Channel::ROOT_TOPIC } do
          match /^\s*([^#]\p{Any}){0,1}*@\S{4,}/, to: ChannelTopics::Channel::Start
        end

        match /.*/, channel: { topic: ::Channel::INVITE_TOPIC }, to: ChannelTopics::Person::Verification
        match /.*/, channel: { topic: ::Channel::POLL_TOPIC }, to: ChannelTopics::Poll::Send
        match /.*/, channel: { topic: ::Channel::CHAT_TOPIC }, to: ChannelTopics::Message::Send
        match /.*/, channel: { topic: ::Channel::ROOM_TOPIC }, to: ChannelTopics::Message::Send
        match /.*/, to: ChannelTopics::Unknown::Handle
      end
    end
  end
end
