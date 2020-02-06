require 'test_helper'

class AddAndManagePeopleTest < ActiveSupport::TestCase
  include Texting::IntegrationTestHelper

  def setup
    super

    root_channel.business.update_attributes name: business_name
  end

  def contact
    @contact ||= OpenStruct.new({
      name: 'Contacticus Rex',
      number: '9193334545',
      email: 'contacticus@rex.com'
    })
  end

  def business_name
    'BIZNESS'
  end

  def contact_file
    'http://blahblch.com/This-Contact.vcf'
  end

  def contact_file_data
    VCardigan.create(version: '3.0').tap do |vcard|
      vcard.fullname contact.name
      vcard.tel contact.number, preferred: 1
      vcard.email contact.email
    end
  end

  test 'add a person by text their contact information' do
    Bandwidth::Media.stub(:download, ->( client, filename ){ filename == contact_file.split('/').last ? [ contact_file_data.to_s ] : raise('Unexpected file name') }) do
      employees[:manager].texts "add to managers, kitchen staff",
        with_attachments: [ contact_file ],
        to: root_channel
    end

    assert_text /Contacticus Rex .* added to/,
      received_by: [ employees[:manager] ]

    employees[:manager].texts '#list', to: root_channel

    assert_text /Contacticus Rex .* add.*(managers.*|kitchen staff.*){2}/,
      received_by: [ employees[:manager] ]

    new_employee = PersonTextTestWrapper.new( Person.where( email: contact.email ).first!, self )

    employees[:manager].texts '#list @kstaff', to: root_channel

    assert_text 'Members', 'Kitchen Staff', 'Contacticus Rex',
      received_by: [ employees[:manager] ], and_not: employees.except(:manager).values

    employees[:manager].texts "#chat kitchen staff : Is Contacticus getting the message!",
      to: root_channel

    assert_text /Is Contacticus getting the message/,
      received_by: [ new_employee ]

    assert_text I18n.t('channel_topics.channel.start.success.sender_header_addendum'),
      received_by: [ employees[:manager] ]

    chat_channel = chat_channel_for(text_messages.last)

    new_employee.texts "I'm here!",
      to: chat_channel

    assert_text /Contacticus Rex[\s\S]*I'm here/,
      received_by: [ employees[:manager] ]

    employees[:manager].texts '#list', to: root_channel

    assert_text *[employees.values.map(&:name), new_employee.name, business_name].flatten,
      received_by: [ employees[:manager] ]

    employees[:manager].texts '#list', to: chat_channel

    assert_text employees[:manager].name, new_employee.name,
      received_by: [ employees[:manager] ]
  end

  test 'add a person and then remove them' do
    Bandwidth::Media.stub(:download, ->( client, filename ){ filename == contact_file.split('/').last ? [ contact_file_data.to_s ] : raise('Unexpected file name') }) do
      employees[:manager].texts "add to managers, kitchen staff",
        with_attachments: [ contact_file ],
        to: root_channel
    end

    contacticus = PersonTextTestWrapper.new( Person.where(mobile: contact.number).first , self)

    assert_text /Contacticus Rex .* added to/,
      received_by: [ employees[:manager] ]

    employees[:manager].texts '#erase Contacticus Rex', to: root_channel

    assert_text 'removed', 'Contacticus',
      received_by: [ employees[:manager] ]

    assert_text 'removed', employees[:manager].display_name,
      received_by: [ contacticus ]
  end
end
