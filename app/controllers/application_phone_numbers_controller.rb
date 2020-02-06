class ApplicationPhoneNumbersController < ApplicationController
  skip_before_action :verify_authenticity_token

  def show
    respond_to :vcf

    business = Business.find( params[:business_id] )
    root_phone_number = ApplicationPhoneNumber.includes(:channels).joins( :channels ).where( channel_people: { person_id: params[:person_id] }, channels: { business_id: params[:business_id], topic: Channel::ROOT_TOPIC } ).first
    room_channel_results = Channel.joins( :text_groups, channel_people: :application_phone_number ).where( channels: { business_id: params[:business_id] }, channel_people: { person_id: params[:person_id] } ).group('channels.id', 'application_phone_numbers.number').pluck( 'channels.id', 'application_phone_numbers.number', 'GROUP_CONCAT(text_groups.name SEPARATOR "||")' )
    room_channels = room_channel_results.map{|channel_id, phone_number, group_names| OpenStruct.new( channel_id: channel_id, phone_number: PhoneNumber.new( phone_number ), group_names: group_names.to_s.split('||').compact.map(&:titleize) )}

    chat_phone_numbers = ApplicationPhoneNumber.available_for_business( params[:business_id], params[:person_id] ).find_all{|apn| !room_channels.map(&:phone_number).include?(apn.number) }
    category = "#{business.display_name} Texting Group"

    #main
    main_contact = VCardigan.create(version: '3.0').tap do |vcard|
      # vcard.categories category
      vcard.name "#{business.display_name};Chatbot;;;;"
      vcard.fullname "#{business.display_name}"
      vcard.categories business.display_name
      vcard.nickname "#{business.display_name} Groups 📱"
      # vcard.tel number_record.number
      vcard[:item1].tel root_phone_number.number.formatted, type: 'text;pref'
      vcard[:item1].send(:'X-ABLabel', '🤖 Chatbot')
      chat_phone_numbers.each_with_index do |chat_phone_number, n|
        key = :"item#{n+2}"
        vcard[ key ].tel chat_phone_number.number.formatted, type: 'text'
        vcard[ key ].send(:'X-ABLabel', '🗨️ Chat')
      end
    end

    all_files = room_channels.inject([main_contact]) do |acc, room_channel|
      contact = VCardigan.create(version: '3.0').tap do |vcard|
        group_description = room_channel.group_names.to_sentence
        # vcard.categories category
        vcard.name "#{business.display_name};#{group_description};;;"
        vcard.fullname "#{business.display_name} #{group_description}"
        vcard.categories business.display_name
        vcard.nickname group_description
        vcard[:item1].tel room_channel.phone_number.formatted, type: 'text;pref'
        vcard[:item1].send(:'X-ABLabel', "💬 #{group_description}")
        # key = :"item#{m+2}"
        # vcard[ key ].tel room_channel.phone_number.formatted, type: ['text']
        # vcard[ key ].send(:'X-ABLabel', "💬 #{}")
      end

      acc << contact
    end

    # To get the card to get recognised you have to put a complex type (with the name)
    # and leave out the name
    filename = "name=\"\\\"#{business.display_name.titleize} Texting.x-vcard\\\"\""
    mimetype = 'text/x-vcard'
    encoding = 'charset=utf-8'
    send_data all_files.join(""), type: [ mimetype, encoding, filename ].join(';')
  end
end
