module ChannelTopics
  class StringRouter
    attr_reader :routes

    def initialize(&block)
      @routes = []

      if block.present?
        instance_eval(&block)
      end
    end

    def scope(args={}, &block)
      scoper = self.class.new(&block)
      scoper.routes.each do |scoped_route|
        routes << [ scoped_route[0].dup, (scoped_route[1] || {}).merge(args)]
      end
    end

    def match(*args)
      routes << args
    end

    def route(target, message_text)
      match = routes.find do |topic|
        string_match = topic.first
        args = topic[1]

        message_text.match( string_match ) &&
          [:channel, :message].all?{|segment| matches_segment?(target, args, segment)}
      end

      handler_klass = (klass = match[1][:to]).respond_to?(:classify) ? klass.classify : klass

      yield handler_klass, match
    end

    def matches_segment?(target, args, segment)
      subject = target.send(segment)
      (args[ segment ] || {}).all? do |meth, mtch|
        begin
          attribute = subject.send(meth)
          case
          when attribute.respond_to?(:grep) then attribute.grep(mtch).present?
          when attribute.respond_to?(:match) then attribute.match(mtch)
          else
            attribute === mtch
          end
        rescue NoMethodError
          false
        end
      end
    end
  end
end
