module ChannelTopics
  module TestHelpers
    def app_phone_number
      '9199000000'
    end

    def generate_text(message, root_number: ApplicationPhoneNumber.first.number)
      channel_phone_number = ApplicationPhoneNumber.last.number
      message.message_generators.map{|g| g.set_values(root_phone_number: root_number.to_s(:url), channel_phone_number: channel_phone_number.to_s(:url)) }.join("/n")
    end

    def normalized(string)
      ActiveSupport::Multibyte::Chars.new(string).normalize.to_s
    end

    def application_phone_number
      @application_phone_number ||= ApplicationPhoneNumber.create( number: app_phone_number )
    end

    def root_channel
      @root_channel ||= ::Channel.create!(business: business, topic: ::Channel::ROOT_TOPIC)
    end

    def chat_channel
      @chat_channel ||= new_chat_channel.tap(&:save!)
    end

    def new_text_message(additional_attrs={})
      msg_attrs = {
        to: app_phone_number, message_to:  app_phone_number,
        message_media: ['https://something/else.crp']
      }

      msg_attrs = msg_attrs.merge(additional_attrs){|k,oldval,newval|
        oldval.kind_of?(Array) && newval.kind_of?(Array) ? newval + oldval : newval
      }

      TextMessage.new(msg_attrs)
    end

    def business
      @business ||= Business.new(facebook_place: FacebookPlace.new)
    end

    def new_chat_channel(attr={})
      default_attr = {
        topic: ::Channel::CHAT_TOPIC,
        business: business
      }

      channel_attr = default_attr.merge(attr){|k,oldval,newval|
        oldval.kind_of?(Array) && newval.kind_of?(Array) ? newval + oldval : newval
      }

      ::Channel.new( channel_attr ).tap do |channel|
        channel.channel_people.each{|cp| cp.application_phone_number = application_phone_number }
      end
    end

    def restaurant_people
      [
        ::Person.new( name: 'Jaime Manager', mobile: '5555551000'),
        ::Person.new( name: 'Terry Chef', mobile: '5555551001'),
        ::Person.new( name: 'Jesse Server', mobile: '5555551002'),
        ::Person.new( name: 'Taylor Server', mobile: '5555551003'),
        ::Person.new( name: 'Francis Dishwasher', mobile: '5555551004')
      ].inject({}){|acc, p| acc[p.name] = p; acc}
    end

    def restaurant_groups
      @restaurant_groups ||= [
        TextGroup.create!( business: business, name: 'managers', people: restaurant_people.values_at('Jaime Manager', 'Terry Chef') ),
        TextGroup.create!( business: business, name: 'kitchen staff', people: restaurant_people.values_at('Terry Chef','Francis Dishwasher')  ),
        TextGroup.create!( business: business, name: 'front of the house', people: restaurant_people.values_at('Jaime Manager', 'Jesse Server', 'Francis Dishwasher')  ),
      ].map{|group| [ group.name, group ]}.to_h
    end

  end
end
