class I18nLazy
  attr_reader :key, :values

  TRANSLATABLE_KEYS = /message/

  def initialize(key, values={})
    @key = key
    @values = values.symbolize_keys
  end

  def set_values(new_values={})
    @values.merge!(new_values.symbolize_keys)
    self
  end

  def exists?(locale=I18n.locale)
    I18n.exists?(key, locale)
  end

  def translate(locale, force: false, &block)
    if force || !translations.has_key?( locale )
      cloned_values = values.clone
      translatable_values = translatable(cloned_values)
      translated_values = block.call( translatable_values, locale, key, cloned_values)
      new_values = values.merge( translated_values ).merge( locale: locale )
      store_translation( locale, new_values )
    end

    return self
  end

  def translatable(value_hash)
    value_hash.find_all{|k,v| k.match(TRANSLATABLE_KEYS) }.to_h
  end

  def store_translation(locale, translated_values)
    if translated_values.keys.to_set >= values.keys.to_set
      translations[locale] = translated_values
    else
      raise ArgumentError, "The translated keys need to be a superset of the original keys"
    end
  end

  def translations
    @translations ||= {}
  end

  def to_s(locale=I18n.locale)
    I18n.t(key, ( translations[ locale ] || values ).merge( locale: locale ) )
  end

  def hash
    instance_values.hash
  end

  def ==(otr)
    otr.kind_of?(self.class) && (instance_values == otr.instance_values)
  end


  class << self
    def from_json(hsh)
      new(*hsh.values_at('key', 'values'))
    end
  end
end
