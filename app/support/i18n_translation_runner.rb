class I18nTranslationRunner < Proc
  class TranslationContext
    include UnicodeFormatting::Helper

    def public_binding
      binding
    end
  end

  class << self
    def load_file(filename, **transformations)
      new( eval( '"' + File.read( filename ) + '"', translation_context_binding), **transformations )
    end

    def load(language, key, **transformations)
      keys = key.split('.')
      path_array = [ 'config', 'locales', language, keys[0..-2], "#{keys[-1]}.translation" ].flatten
      path = Rails.root.join(*path_array)
      new( eval( '"' + File.read( path ) + '"', translation_context_binding) )
    end

    def translation_context_binding
      @translation_context_binding ||= TranslationContext.new.public_binding
    end

    def new(string, **transformations)
      runner = super(){|key,input_params|
        # string % transform(key, params, transformations)
        params = input_params.merge( default_params )
        I18n.interpolate(string, transform(key, params, transformations))
      }
    end

    def default_params
      {
        application_name: I18n.t(:application_name)
      }
    end

    def transform(key, params, transformations)
      return {} unless params.present?

      new_params = params.clone

      transformations.each do |transform_key, transformation|
        if p_val = new_params[transform_key]
          new_params[transform_key] = if transformation.respond_to?(:call)
            transformation.call(key,params,p_val)
          else
            p_val.send( *transformation )
          end
        else
          new_params[transform_key] = transformation.call(key,params)
        end
      end

      new_params.each do |k,v|
        if v.respond_to?(:to_sentence) && v.all?{|elt| elt.kind_of?(String)}
          new_params[k] = v.to_sentence
        end

        if v.respond_to?(:join) && v.all?{|elt| elt.respond_to?(:join) }
          new_params[k] = v.map{|elts| elts.join("\n") }.join("\n")
        end
      end

      new_params
    end
  end
end
