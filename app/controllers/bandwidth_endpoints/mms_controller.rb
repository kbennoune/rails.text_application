module BandwidthEndpoints
  class MmsController < BaseController
    http_basic_authenticate_with Rails.application.secrets.bandwidth_callback_auth

    def create
      text_message = TextMessage::BandwidthApi.receive(params, request)

      if text_message.save
        TextMessageWorker::SetChannel.perform_async( text_message.id )

        head :accepted
      else
        head :bad_request
      end
    end

    def callback

      puts "Callback received: #{params.inspect}"
    end
  end
end

# Add people
# Start a text chain
# Send a reminder/message for later
# Add a group
# Send task/task list
# Remove person
# Set a schedule
# Create a named group with it's own phone number

# Entities:
# Person
# - Name
# - Phone #
# - Picture
# - etc
# Channel
# (there can be multiple channels per phone number/contact)
# Is a channel the same as a conversation???
# - phone number
# - current state(s) (has a ttl and is refreshed)
# - mute/digest ?
# Group
# - channel
# - people
# Task
# Message
