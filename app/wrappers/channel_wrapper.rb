class ChannelWrapper < SimpleDelegator
  include ActiveModel::Serializers::JSON

  attr_reader :channel, :is_active

  def initialize( channel, is_active: false )
    @is_active = is_active
    super( channel )
  end
end
