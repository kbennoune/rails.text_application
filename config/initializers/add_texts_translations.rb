module I18n
  module Backend
    module Base
      def load_texts(filename)
        path = Pathname.new(filename)
        lang = path.relative_path_from( Rails.root.join('config', 'locales') ).split.first.to_s

        language_transforms = if path.join('transforms.rb').exist?
          load_rb( path.join('transforms.rb').to_s )
        end

        global_transforms = if path.join('..','..','config','transforms.rb').exist?
          load_rb(path.join('..','..','config','transforms.rb').to_s)
        end

        transforms = (global_transforms || {}).merge( language_transforms || {} )

        texts = Dir[ path.parent.join('**','**.translation') ].inject({}) do |acc, file|
          file_path = Pathname.new( file )
          rel = file_path.relative_path_from(path).each_filename.to_a
          keys = [rel[1..-2], rel[-1].to_s.split('.').first].flatten

          hsh = keys.reverse.inject( I18nTranslationRunner.load_file(file, transforms[ keys.join('.') ] || {} ) ){|a, k| { k.to_sym => a } }

          acc.deep_merge(hsh)
        end

        { lang.to_sym => texts }

      end
    end
  end
end
