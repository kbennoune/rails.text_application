require 'test_helper'

# test 'it sends a simple text message if the user'

class TextMessageGeneratorTest < ActiveSupport::TestCase
  OPEN = '⧼' #'❮'
  CLOSE = '⧽' #'❯'

  def normalized(string)
    ActiveSupport::Multibyte::Chars.new(string).normalize.to_s
  end

  def setup
    super

    I18n.backend.store_translations(:en,
      some_key: '%{what} translation will work here',
      another_key: "%{some} translations won't work here"
    )
  end

  def translated(string, target, source=nil)
    [ Translation::GoogleApi::TranslationResponse.new( OpenStruct.new( translated_text: string, to_s: string ), target: target, source: source ) ]
  end

  def recipient(channel=nil)
    if channel.present?
      receiver.channel_people.find{|cp| cp.channel == channel } || ChannelPerson.new( channel: channel, person: receiver )
    else
      ChannelPerson.new( person: receiver, channel: Channel.new )
    end
  end
end

class TextMessageGeneratorTestWithSameLocale < TextMessageGeneratorTest
  def sender
    @sender ||= Person.new(name: 'Message Sender', preferred_language: :en, mobile: '12223459999')
  end

  def receiver
    @receiver ||= Person.new(name: 'Message Receiver', preferred_language: :en, mobile: '12223458888')
  end

  test 'will send the messages if there is a translation' do
    text_message = TextMessage.new original_sender: sender, message_generator_keys: [I18nLazy.new(:some_key, what: 'A'), I18nLazy.new(:another_key, some: 'no other')]
    generator = TextMessageGenerator.new(recipient, text_message)

    expected_string = <<~EOE.strip
      A translation will work here
      no other translations won't work here
    EOE

    assert_match expected_string, generator.to_s
  end

  test 'it will generate a message with a header addendum' do
    I18n.backend.store_translations(:en, header_emoji: '🚧' )
    text_message = TextMessage.new header_addendum_key: I18nLazy.new(:header_emoji), sender: sender, message_generator_keys: [I18nLazy.new(:some_key, what: 'A'), I18nLazy.new(:another_key, some: 'no other')]
    generator = TextMessageGenerator.new(recipient, text_message)

    assert_match '🚧', generator.to_s.split("\n")[0]
  end

  test 'it will not translate the original message if there is no translation' do
    sender.preferred_language = :es
    receiver.preferred_language = :es

    I18n.backend.store_translations(:en, msg_key: '%{message} is %{what}...')

    expected_string = <<~EOE.strip
      A message is A...
    EOE

    text_message = TextMessage.new original_sender: sender, message_generator_keys: [I18nLazy.new(:msg_key, what: 'A', message: 'A message')]
    generator = TextMessageGenerator.new(recipient, text_message)

    assert !generator.translation_exists?
    assert_match expected_string, generator.to_s
  end
end

class TextMessageGeneratorTestWithDifferentLocale < TextMessageGeneratorTest
  def sender
    @sender ||= Person.new(name: 'Message Sender', preferred_language: :en, mobile: '12223459999')
  end

  def receiver
    @receiver ||= Person.new(name: 'Message Receiver', preferred_language: :es, mobile: '12223458888')
  end

  test 'will translate the entire message when there is no translation' do
    text_message = TextMessage.new original_sender: sender, message_generator_keys: [I18nLazy.new(:some_key, what: 'A'), I18nLazy.new(:another_key, some: 'no other')]
    generator = TextMessageGenerator.new(recipient, text_message)

    original = <<~EOE.strip
      A translation will work here
      no other translations won't work here
    EOE

    spanish_translation = <<~EOS
      Una traducción funcionará aquí
      ninguna otra traducción no funcionará aquí
    EOS

    combined_string = [original,'🇪🇸 En Español 🇪🇸',spanish_translation].join("\n")

    generator.translation_client.stub(:translate, translated( spanish_translation, :es, :en )) do
      assert_match combined_string, generator.to_s
    end
  end

  test 'it will translate the values but use the localized template when there is a translation' do
    I18n.backend.store_translations(:en,
      title_key: '%{name} is a person',
      message_key: "[English Template]: %{message}"
    )

    I18n.backend.store_translations(:es,
      title_key: '%{name} es una persona',
      message_key: "[Plantilla Española]: %{message}"
    )

    text_message = TextMessage.new original_sender: sender, message_generator_keys: [I18nLazy.new(:title_key, name: 'Bill'), I18nLazy.new(:message_key, message: 'This is a message that will be translated!')]
    generator = TextMessageGenerator.new(recipient, text_message)

    spanish_message_translation = "Este es un mensaje que será traducido!"

    combined_string = <<~EOT.strip
      Bill es una persona
      [Plantilla Española]: This is a message that will be translated!

      🇪🇸 En Español 🇪🇸

      Bill es una persona
      [Plantilla Española]: Este es un mensaje que será traducido!
    EOT

    generator.translation_client.stub(:translate, translated( spanish_message_translation, :es, :en )) do
      assert_match combined_string, generator.to_s
    end
  end
end

class TextMessageGeneratorTestWithNoSender < TextMessageGeneratorTest
  def receiver
    @receiver ||= Person.new(name: 'Message Receiver', preferred_language: :en, mobile: '12223458888')
  end

  test 'it will send the original message if there is a translation' do
    text_message = TextMessage.new message_generator_keys: [I18nLazy.new(:some_key, what: 'A'), I18nLazy.new(:another_key, some: 'no other')]
    generator = TextMessageGenerator.new(recipient, text_message)

    original = <<~EOE.strip
      A translation will work here
      no other translations won't work here
    EOE

    assert_match original, generator.to_s
  end

  test 'it will send a translation of the original message if there is no translation' do
    text_message = TextMessage.new message_generator_keys: [I18nLazy.new(:some_key, what: 'A'), I18nLazy.new(:another_key, some: 'no other')]
    generator = TextMessageGenerator.new(recipient, text_message)

    receiver.preferred_language = :es

    original = <<~EOE.strip
      A translation will work here
      no other translations won't work here
    EOE

    spanish_translation = <<~EOS
      Una traducción funcionará aquí
      ninguna otra traducción no funcionará aquí
    EOS

    combined_string = [original,'🇪🇸 En Español 🇪🇸',spanish_translation].join("\n")

    generator.translation_client.stub(:translate, translated( spanish_translation, :es, :en )) do
      assert_match combined_string, generator.to_s
    end
  end
end

class TextMessageGeneratorHeaderTest < TextMessageGeneratorTest
  def sender
    @sender ||= Person.new(name: 'Message sender', preferred_language: :en, mobile: '12223459999')
  end

  def receiver
    @receiver ||= Person.new(name: 'Message Receiver', preferred_language: :en, mobile: '12223458888')
  end

  test 'it adds the message sender name to the message' do
    text_message = TextMessage.new sender: sender, message_generator_keys: [I18nLazy.new(:some_key, what: 'A'), I18nLazy.new(:another_key, some: 'no, other')]

    generator = TextMessageGenerator.new(recipient, text_message)
    assert_match UnicodeFormatting.format(:bold_italic, sender.name.titleize), generator.to_s
  end

  test 'it will work without a sender' do
    text_message = TextMessage.new sender: nil, message_generator_keys: [I18nLazy.new(:some_key, what: 'A'), I18nLazy.new(:another_key, some: 'no, other')]

    generator = TextMessageGenerator.new(recipient, text_message)
    assert_match I18n.t(:some_key, what: 'A'), generator.to_s
  end

  test 'it will include groups if there are channel groups' do
    groups = [ TextGroup.new(name: 'managers'), TextGroup.new( name: 'Kitchen Staff') ]
    channel = Channel.new topic: ::Channel::CHAT_TOPIC, text_groups: groups

    text_message = TextMessage.new channel: channel, sender: sender, message_generator_keys: [I18nLazy.new(:some_key, what: 'A'), I18nLazy.new(:another_key, some: 'no, other')]
    generator = TextMessageGenerator.new(recipient(channel), text_message)
    assert_match normalized("#{OPEN}Managers & Kitchen Staff#{CLOSE}"), normalized(generator.to_s)
  end

  test 'it will shorten long groups if there are channel groups' do
    groups = [ TextGroup.new(name: 'prep'), TextGroup.new( name: 'A big massive group name'), TextGroup.new( name: 'cooks') ]
    channel = Channel.new topic: ::Channel::CHAT_TOPIC, text_groups: groups

    text_message = TextMessage.new channel: channel, sender: sender, message_generator_keys: [I18nLazy.new(:some_key, what: 'A'), I18nLazy.new(:another_key, some: 'no, other')]
    generator = TextMessageGenerator.new(recipient(channel), text_message)
    assert_match normalized("#{OPEN}Prep, A Big Mas… & Cooks#{CLOSE}") , normalized(generator.to_s)
  end

  test 'it will truncate the list if there are a lot of channel groups' do
    groups = [ TextGroup.new(name: 'managers'), TextGroup.new( name: 'cooks'), TextGroup.new( name: 'bakers'), TextGroup.new( name: 'servers') ]
    channel = Channel.new topic: ::Channel::CHAT_TOPIC, text_groups: groups

    text_message = TextMessage.new channel: channel, sender: sender, message_generator_keys: [I18nLazy.new(:some_key, what: 'A'), I18nLazy.new(:another_key, some: 'no, other')]
    generator = TextMessageGenerator.new(recipient(channel), text_message)
    assert_match normalized("#{OPEN}Managers, Cooks, Bakers & 1 more#{CLOSE}") , normalized(generator.to_s)
  end

  test 'it will include any unaffiliated users in the header' do
    business = Business.create!
    managers = [ Person.create!( name: 'Manager1'), Person.create!( name: 'Manager2')]
    groups = [ TextGroup.create!(business: business, name: 'managers', people: managers) ]

    channel = Channel.create! business: business, topic: ::Channel::CHAT_TOPIC, text_groups: groups
    TextChannelWorker::AddFromGroup.drain

    channel.people << receiver
    channel.people << sender
    channel.people << Person.create!( name: 'Someone else' )
    text_message = TextMessage.new channel: channel, sender: sender, message_generator_keys: [I18nLazy.new(:some_key, what: 'A'), I18nLazy.new(:another_key, some: 'no, other')]

    generator = TextMessageGenerator.new(recipient(channel), text_message)
    assert_match normalized("#{OPEN}Someoneel…, Messagese… & 1 more#{CLOSE}"), normalized(generator.to_s)
  end
end
