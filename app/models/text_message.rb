class TextMessage < ApplicationRecord
  belongs_to :channel, optional: true
  serialize :remote_headers, JSON
  attribute :message_media, :json, default: []
  serialize :times, JSON
  serialize :to, JSON
  serialize :message_to, JSON

  attribute :message_from, :phone_number
  attribute :original_message_from, :phone_number

  attribute :remote_events, :json, default: []

  attribute :async, :boolean
  attribute :send_in, :integer

  attribute :message_generator_keys, :json, default: []
  attribute :header_addendum_key, :json, default: nil

  attribute :to_people, :json, default: []

  belongs_to :sender, class_name: 'Person', optional: true
  belongs_to :original_sender, class_name: 'Person', optional: true

  delegate :id, to: :sender, prefix: true, allow_nil: true

  belongs_to :responding_to_text_message, optional: true, class_name: self.name

  after_validation :set_message_generator_key_from_json

  self.inheritance_column = :klass_type

  APP_STATUS_QUEUED = 'queued'
  APP_STATUS_SENT = 'sent'
  APP_STATUS_RECEIVED = 'received'
  APP_DIRECTION_IN = 'in'
  APP_DIRECTION_OUT = 'out'

  after_commit :queue_async, on: :create, if: :async

  def queue_async
    case
    when send_at.present? then
      TextMessageWorker::Send.perform_at( send_at, self.id )
    when send_in.present? then
      TextMessageWorker::Send.perform_in( send_in, self.id )
    else
      TextMessageWorker::Send.perform_async( self.id )
    end
  end

  class << self
    include UnicodeFormatting::Helper

    def new_channel_params(channel:, original_sender: nil, original_from: nil, media: [], **options)
      {
        channel: channel,
        app_direction: TextMessage::APP_DIRECTION_OUT,
        app_status: TextMessage::APP_STATUS_QUEUED,
        message_media: media, original_message_from: original_from,
        original_sender: original_sender,
        async: true
      }.merge( options )
    end

    def send_out!( **params )
      create!( new_channel_params( **params ) )
    end

    def out( **params )
      new( new_channel_params( **params ) )
    end

    def message_format(sender, text)
      if sender.respond_to?(:display_name)
        [italic("#{sender.display_name} said:"), text].join("\n")
      else
        text
      end
    end
  end

  def header_addendum
    @header_addendum ||= if header_addendum_key.present?
      I18nLazy.from_json(header_addendum_key)
    end
  end

  def message_generator_keys=(value)
    if value.kind_of?(Array)
      super
    else
      super([value])
    end
  end

  def to_people=(value)
    if value.kind_of?(Array)
      super
    else
      super([value])
    end
  end

  def message_generators
    message_generator_keys.map{|gen_keys| I18nLazy.from_json(gen_keys) }
  end

  def translation_exists?(locale=I18n.locale)
    message_generators.all?{|loc| loc.exists?(locale) }
  end

  def to=(value)
    if value.respond_to?(:each)
      super
    else
      super([value])
    end
  end

  def to
    if (value = super).respond_to?(:map)
      value.map{|pn| PhoneNumber.new(pn) }
    elsif value.present?
      PhoneNumber.new(value)
    else
      value
    end
  end

  def display_header_description?
    !hide_header_description?
  end

  class BandwidthApi
    class << self
      def receive(params,request)
        self.new(params, request).text_message
      end
    end

    attr_reader :params, :request

    def initialize(params, request, text_message: nil)
      @params = params
      @request = request
      @text_message = text_message || TextMessage.new
    end

    def attributes
      @attributes ||= base_attributes.merge(
        **app_attributes, **message_attributes, **remote_attributes
      )
    end

    def text_message
      @text_message.tap{|tm| tm.attributes = attributes }
    end

    def base_attributes
      {
        type: params[:eventType],
        time: params[:time],
        times: [params[:time]],
        description: params[:deliveryDescription],
        to: [params[:to]],
      }
    end

    def app_attributes
      {
        app_status: TextMessage::APP_STATUS_RECEIVED,
        app_direction: TextMessage::APP_DIRECTION_IN,
        remote_request_at: Time.now
      }
    end

    def message_attributes
      {
        message_id: params[:messageId],
        message_time: params[:time],
        message_direction: params[:direction],
        message_to: [params[:to]],
        message_from: params[:from],
        message_text: params[:text].respond_to?(:gsub) ? UnicodeFormatting.respace(params[:text]) : params[:text],
        message_applicationId: params[:applicationId],
        message_media: params[:media]
      }
    end

    def remote_attributes
      {
        remote_headers: request.headers.to_h.find_all{|k,v| v.kind_of?(String)}.map{|k,v| [k,encoded_copy(v)]}.to_h,
        remote_body: encoded_copy(request.body.read.html_safe)
      }
    end

    def encoded_copy(str)
      if str.encoding.name != "UTF-8"
        str.clone.force_encoding('UTF-8')
      else
        str.clone
      end
    end
  end

  private

    def set_message_generator_key_from_json
      if message_generator_keys.present? && message_generator_keys[0].respond_to?(:has_key?) && message_generator_keys[0].has_key?('key')
        self.message_generator_key = message_generator_keys.dig(0,'key')
      end
    end
end
