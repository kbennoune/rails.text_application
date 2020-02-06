class PhoneNumber
  attr_reader :digits
  delegate :as_json, :blank?, to: :digits, prefix: false

  def initialize(digits)
    @digits = normalize(digits)
  end

  def normalize(number_string)
    if number_string.present? && number_string.respond_to?(:to_s) && number_string.to_s.match(/^1\d{10}\z/)
      number_string.to_s
    elsif number_string.present? && number_string.respond_to?(:to_s)
      number_string.to_s.gsub(/[^\d]/,'').gsub(/^(1|)(\d{10})$/,'1\2')
    else
      number_string
    end
  end

  def formatted(format=:standard)
    display_digits = if digits.first == '1' && digits.length == 11
      digits[1..-1]
    else
      digits
    end

    options = format_options[ format ] || format_options[ :standard ]
    ActionController::Base.helpers.number_to_phone(display_digits, **options)
  end

  def format_options
    {
      standard: { area_code: true },
      url: { delimiter: '.' }
    }
  end

  def to_s(format=nil)
    if format.blank?
      digits.to_s
    else
      formatted(format)
    end
  end

  def ==(value)
    digits == normalize(value)
  end

  def hash
    digits.hash
  end

  alias eql? ==

  class Type < ActiveModel::Type::String
    def type
      :phone_number
    end

    def cast(value)
      deserialize(value)
    end

    def serialize(value)
      if value.kind_of?(::PhoneNumber)
        value.to_s
      else
        deserialize(value).to_s
      end
    end

    def deserialize(value)
      ::PhoneNumber.new(value)
    end
  end
end
