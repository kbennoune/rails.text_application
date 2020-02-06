module ChannelTopics
  module Poll
    class Start < ChannelTopics::Channel::Start

      def new_channel_topic
        ::Channel::POLL_TOPIC
      end
      
    end
  end
end
