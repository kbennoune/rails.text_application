class TextMessageWrapper < SimpleDelegator
  include ActiveModel::Serializers::JSON

  attr_reader :recipient, :generator

  def initialize( message, person)
    @recipient = ChannelPerson.new( channel: message.channel, person: person )
    @generator = TextMessageGenerator.new( @recipient, message, values: { channel_phone_number: '#########', root_phone_number: '##########'}, display_header: false )
    super( message )
  end

  def message_text
    begin
      generator.to_s.strip
    rescue I18n::MissingInterpolationArgument => e
      <<~EOS

      EOS

    end
  end

end
