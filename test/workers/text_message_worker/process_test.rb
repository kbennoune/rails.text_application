require 'test_helper'

module TextMessageWorker
  class ProcessTest < ActiveSupport::TestCase

    def received_text_message( message_text:, channel:, message_media: [] )
      TextMessage.create!(
        app_status: TextMessage::APP_STATUS_RECEIVED,
        channel: channel,
        message_text: message_text,
        message_media: message_media
      )
    end

    def sender
      @sender ||= ::Person.create!( name: 'Jaime', mobile: '5555551000')
    end

    def root_channel
      @root_channel ||= Channel.create!( topic: Channel::ROOT_TOPIC, business: Business.new ).tap do |channel|
        channel.people << sender
      end
    end

    def sends
      <<-EOT
        This is a text
        ready to send...
      EOT
    end

    def assert_matcher_args(topic)
      assert_equal sends, topic.text_message.message_text
      assert_equal root_channel, topic.channel
      assert topic.called
    end

    def stub_topic(text_message, channel)
      stubbed_topic.tap do |topic|
        topic.text_message = text_message
        topic.channel = channel
      end
    end

    def stubbed_topic
      @stubbed_topic ||= begin
        Object.new.tap do |topic|
          class << topic
            attr_accessor :text_message, :channel
            attr_reader :called, :responded
            def call
              @called = true
            end
          end
        end
      end
    end

    test 'use ChannelTopics class to pick message topic' do
      text_message = received_text_message( message_text: sends, channel: root_channel )
      worker = TextMessageWorker::Process.new

      ChannelTopics::Matcher.stub(:topic, method(:stub_topic)) do
        worker.perform( text_message.id )
      end

      assert_matcher_args(stubbed_topic)

      worker.pick_message_topic do |unstubbed_topic|
        assert_kind_of ChannelTopics::Processor, unstubbed_topic
        assert_respond_to :call, unstubbed_topic
        assert_respond_to :response, unstubbed_topic
      end
    end
  end
end
