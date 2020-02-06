module ChannelTopics
  class ContactFile < SimpleDelegator
    attr_reader :data

    def initialize(data='')
      @data = normalize(data) || ''
      super(@data)
    end

    def normalize(str)
      str.gsub("\r\n","\n").gsub(/^\s+/,'')
    end

    def filetype
      if match(/^BEGIN:VCARD/)
        :vcard
      end
    end

    def version
      if mt = match(/VERSION:(\d+(.\d+|))/)
        mt[1]
      end
    end

    def vcard?
      filetype == :vcard
    end

    def person_data
      {
        name: contact_data.fn.first.values.first,
        mobile: mobile_number,
        timezone:  contact_data.tz.try(:first).try(:values).try(:first),
        email: contact_data.email.try(:first).try(:values).try(:first),
        vcard: @data
      }
    end

    def mobile_number
      contact_preferred_mobile_number || contact_mobile_number || contact_preferred_number
    end

    def contact_preferred_mobile_number
      contact_data.tel.find{ |tel|
        tel.params['preferred'] && type_params_in(tel,'CELL','CAR')
      }.try(:values).try(:first)
    end

    def contact_mobile_number
      contact_data.tel.find{ |tel|
        type_params_in(tel,'CELL','CAR')
      }.try(:values).try(:first)
    end

    def contact_preferred_number
      contact_data.tel.find{ |tel|
        tel.params['preferred']
      }.try(:values).try(:first)
    end

    def type_params_in(tel, *types)
      [tel.params['type']].flatten.compact.map{|elt| elt.split(',') }.flatten.any?{|type| types.include?( type.upcase ) }
    end

    def photo_binary
      contact_data.photo.try(:first).try(:values).try(:first)
    end

    def contact_data
      @contact_data ||= if vcard?
        VCardigan.parse( self )
      end
    end
  end
end
