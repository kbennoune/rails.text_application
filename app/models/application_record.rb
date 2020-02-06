class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  raise('Fuzzily has been upgraded, remove fuzzily overrides') if Fuzzily::VERSION != '0.3.3'

  extend(Fuzzily::Searchable::Rails4ClassMethods)

  def self.make_field_fuzzily_searchable(field, options={})
    class_variable_defined?(:"@@fuzzily_searchable_#{field}") and return

    _o = OpenStruct.new(
      :field                  => field,
      :trigram_class_name     => options.fetch(:class_name, 'Trigram'),
      :trigram_association    => "trigrams_for_#{field}".to_sym,
      :update_trigrams_method => "update_fuzzy_#{field}!".to_sym,
      :async                  => options.fetch(:async, false)
    )

    _add_trigram_association(_o)

    singleton_class.send(:define_method,"find_by_fuzzy_#{field}".to_sym) do |*args|
      _find_by_fuzzy(_o, *args)
    end

    singleton_class.send(:define_method,"bulk_update_fuzzy_#{field}".to_sym) do
      _bulk_update_fuzzy(_o)
    end

    # DISABLED
    # define_method _o.update_trigrams_method do
    #   if _o.async && self.respond_to?(:delay)
    #     self.delay._update_fuzzy!(_o)
    #   else
    #     _update_fuzzy!(_o)
    #   end
    # end

    define_method _o.update_trigrams_method do
      if _o.async #&& self.respond_to?(:delay)
        UpdateFuzzyWorker.perform_async(self.class.name, self.id, self.send(_o.field), _o.to_h)
      else
        _update_fuzzy!(_o)
      end
    end

    after_save do |record|
      next unless record.saved_change_to_attribute?(field)

      record.send(_o.update_trigrams_method)
    end

    class_variable_set(:"@@fuzzily_searchable_#{field}", true)
    self
  end
end
