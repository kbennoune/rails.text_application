class UpdateFuzzyWorker
  include Sidekiq::Worker

  def perform(klass_name, id, value, configs)
    _o = OpenStruct.new(configs)
    klass = klass_name.constantize

    object = if klass.instance_methods.include?(:"#{_o.field}=")
      klass.new( :id => id, _o.field => value)
    else
      object = klass.find(id)
    end

    object.send(:_update_fuzzy!, _o)
  end
end
