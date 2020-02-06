class ChannelForRecipients
  attr_reader :topic, :sender, :business_id, :started_by, :text_groups, :receivers

  def initialize(topic, sender:, business_id:, started_by:, text_groups:, receivers: )
    @topic = topic
    @sender = sender
    @business_id = business_id
    @started_by = started_by
    @text_groups = text_groups
    @receivers = receivers
  end

  def receiver_ids
    receivers.map(&:id)
  end

  def channel
    @channel ||= if (existing_channel = find_existing_channel).present?
      existing_channel
    else
      new_channel
    end
  end

  def new_channel
    ::Channel.new(
      topic: topic, business_id: business_id,
      started_by_person: started_by, text_groups: text_groups
    )
  end

  def find_existing_channel
    ::Channel.matching_active( business_id, receiver_ids, text_groups.map(&:id), topic: topic ).last
  end
end
