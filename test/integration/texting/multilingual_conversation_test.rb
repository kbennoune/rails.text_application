require 'test_helper'

class MultilingualConversationTest < ActiveSupport::TestCase
  include Texting::IntegrationTestHelper

  def around(&test)
    super do
      UpdateFuzzyWorker.stub(:perform_async, ->(*args){ UpdateFuzzyWorker.new.perform(*args) } ) do
        test.call
      end
    end
  end

  def setup
    super

    register_translations
  end

  def register_translations
    register_translation('en', 'es', "Who is working the special event tomorrow?", "¿Quién está trabajando en el evento especial de mañana?")
    register_translation('es', 'en', "Voy a estar allí a las 5", "I'm going to be there at 5")
    register_translation('en', 'es', "Going to be asleep. Worked a double last night!", "Va a estar dormido. ¡Trabajó un doble anoche!")
  end

  test 'carry on a conversation between several Spanish speakers and english speakers' do
    employees[:manager].texts "#add the chef, first server, second server, first cook and second cook to all staff",
      to: root_channel

    employees[:server1].texts "#espanol", to: root_channel
    assert_text 'idioma', 'Español', received_by: [employees[:server1]]

    employees[:cook1].texts '#Espanol', to: root_channel
    assert_text 'idioma', 'Español', received_by: [employees[:cook1]]

    spanish_speakers = employees.slice(:server1, :cook1)
    english_speakers = employees.slice(:manager, :chef, :cook2, :server2)

    employees[:manager].texts "#chat kitchen staff : Who is working the special event tomorrow?",
      to: root_channel

    assert_text 'Quién está trabajando en el evento especial de mañana',
      received_by: spanish_speakers.values,
      and_not: english_speakers.values

    chat_channel = chat_channel_for(text_messages.last)

    employees[:server1].texts "Voy a estar allí a las 5", to: chat_channel

    assert_text 'Voy a estar allí a las 5',
      received_by: spanish_speakers.except(:server1).values

    assert_text "I'm going to be there at 5",
      received_by: english_speakers.values,
      and_not: spanish_speakers.values

    employees[:cook2].texts 'Going to be asleep. Worked a double last night!', to: chat_channel

    assert_text "Going to be asleep. Worked a double last night!",
      received_by: employees.except(:cook2).values

    assert_text "Va a estar dormido. ¡Trabajó un doble anoche!",
      received_by: spanish_speakers.values,
      and_not: english_speakers.values
  end


  def register_translation(source, target, original, translation)
    request_body = { format: 'text', model: nil, q: [ original], source: source, target: target}
    response_body = { data: { translations: [ { translatedText: translation } ] } }
    stub_request(:post, "https://translation.googleapis.com/language/translate/v2").
      with(
        body: request_body.to_json,
        headers: {
    	  'Accept'=>'*/*',
    	  'Content-Type'=>'application/json'
        }).
      to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type'=>'application/json' })
  end
end
