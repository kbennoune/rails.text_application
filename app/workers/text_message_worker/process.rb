module TextMessageWorker
  class Process
    include Sidekiq::Worker

    attr_reader :text_message, :message_topic

    def perform(text_message_id)
      @text_message = TextMessage.find(text_message_id)
      @message_topic = pick_message_topic
      message_topic.call
    end

    def channel
      text_message.channel
    end

    def pick_message_topic
      ChannelTopics::Matcher.topic(text_message, channel)
    end
  end
end
