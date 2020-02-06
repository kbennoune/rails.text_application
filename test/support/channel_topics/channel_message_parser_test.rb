require 'test_helper'

class ChannelTopics::ChannelMessageParserTest < ActiveSupport::TestCase

  def finder(collection)
    Proc.new{|recipients|
      recipients.map{|recipient| collection << recipient; [recipient, recipient]}.to_h
    }
  end

  test 'extracting names and messages' do
    msg = "#something with John Wilkes Booth, Jon-Joe Shelvy, Ronaldo Luís Nazário de Lima and group: This is the message"
    recipients = []
    parser = ChannelTopics::ChannelMessageParser.new(msg, &finder(recipients) )

    parser.recipients
    assert_equal 'This is the message', parser.message
    assert_equal ['John Wilkes Booth', 'Jon-Joe Shelvy', 'Ronaldo Luís Nazário de Lima', 'group'].to_set, recipients.to_set
  end

  test 'extracting mentions and messages with line seperated message' do
    msg = "@john, @Jon-Joe @Ronaldo.Luís.Nazário and group\nThis is some kind of message"
    recipients = []
    parser = ChannelTopics::ChannelMessageParser.new(msg, &finder(recipients) )

    parser.recipients
    assert_equal 'This is some kind of message', parser.message
    assert_equal ['@john', '@Jon-Joe', '@Ronaldo.Luís.Nazário', 'group'].to_set, recipients.to_set
  end

  test 'extracting mentions and messages with colon separated message' do
    msg = "@john, @Jon-Joe @Ronaldo.Luís.Nazário and group: This is some kind of message"
    recipients = []
    parser = ChannelTopics::ChannelMessageParser.new(msg, &finder(recipients) )

    parser.recipients
    assert_equal 'This is some kind of message', parser.message
    assert_equal ['@john', '@Jon-Joe', '@Ronaldo.Luís.Nazário', 'group'].to_set, recipients.to_set
  end

  test 'extracting mentions and messages with inline message' do
    msg = "@john, @Jon-Joe @Ronaldo.Luís.Nazário and @group This is some kind of message"
    recipients = []
    parser = ChannelTopics::ChannelMessageParser.new(msg, &finder(recipients) )

    parser.recipients
    assert_equal 'This is some kind of message', parser.message
    assert_equal ['@john', '@Jon-Joe', '@Ronaldo.Luís.Nazário', '@group'].to_set, recipients.to_set
  end

  test 'extracting inline mentions' do
    msg = message_text =<<~EOM
      #chat with @gerentes @ariane @emerson
      Alguém pode trabalhar hoje, especialmente @ariane e @emerson
      Precisamos de um substituto para @DaviAzevedo e manuelamaldonado
    EOM

    recipients = []
    parser = ChannelTopics::ChannelMessageParser.new(msg, &finder(recipients) )

    parser.recipients

    assert_equal message_text.lines[1..-1].join("").strip, parser.message
    assert_equal ["@gerentes", "@ariane", "@emerson", "@DaviAzevedo"].to_set, recipients.to_set
  end
end
