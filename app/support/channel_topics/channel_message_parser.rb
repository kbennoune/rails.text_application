module ChannelTopics
  class ChannelMessageParser
    attr_reader :text, :finder

    def initialize(text, &finder)
      @text = text.to_s
      @finder = finder
    end

    def recipient_matches
      @recipient_matches ||= finder.call(potential_recipients_for_matches)
    end

    def recipients
      recipient_matches.values
    end

    def recipient_strings
      recipient_matches.keys
    end

    def potential_recipients_for_matches
      potential_recipients.find_all do |recipient|
        if message_start_index.blank?
          true
        else
          recipient.match(/^@/) || message_lines[0...(message_start_index)].join(' ').match(Regexp.escape(recipient))
        end
      end
    end

    def message
      @message ||= begin
        if start_index = message_start_index
          message_lines[start_index..-1].join("\n").to_s.gsub(/^\s*:\W*/,'')
        else
          message_lines.map{|line| line.gsub(/(|and )@[\S]+([:\s]|$)/,'')}.find_all{|line| line.match(/\S/) }.join("\n")
        end
      end
    end

    def message_lines
      @message_lines ||= text.split(/\s*(?:(?=:)|\n)\s*/)
    end

    def message_start_index
      (@message_start_index ||= [ calculate_start_index ]).first
    end

    def calculate_start_index
      message_lines.find_index do |line|        
        modified_line = potential_recipients.compact.inject(line){|acc,name| acc.gsub(/(?:to\s*|)(?:[^a-zA-Z\d\s\-])*#{Regexp.escape(name)}(?:[^a-zA-Z\d\s\-]|[\s])*/, '') }
        (!modified_line.downcase.match(identifier) && !modified_line.match(/^(\W*and\W)+$/)) ||
          modified_line.match(/^:/) ||
          modified_line == line
      end
    end

    def potential_recipients
      @potential_recipients ||= begin
        mentioned = []
        others = []
        lines = text_without_identifier.split(/\s*(?:(?=:)|\n)\s*/)
        lines.each_with_index do |line,idx|
          mentioned_in_line = []
          line_without_mentions =  line.gsub(/(@[^\s,]+)(?=[,:\s]|$)/) do |match|
            mentioned_in_line << match.strip
            ''
          end
          others_in_line = line_without_mentions.gsub(/(^| )and /, ',').scan(ChannelTopics::PeopleManager::NAMES_REGEX).map(&:strip)

          break unless idx == 0 || mentioned_in_line.present?

          mentioned.concat mentioned_in_line
          unless others_in_line.size == 1 && mentioned_in_line.size > 0 && (start_index = line.index(others_in_line.last)) && line.length == (start_index + others_in_line.last.length) && !line.match(/(&|and|,)\s+#{Regexp.escape(others_in_line.last)}$/)
            others.concat others_in_line
          end
        end

        mentioned + others
      end
    end

    def text_without_identifier
      start_index = text.downcase.index(identifier)
      new_string = [text[0,start_index],text[(start_index + identifier.length)..-1]].join('')
    end

    def identifier
      @identifier ||= begin
        if text.downcase.match(/^\s*#[^\W,@]+\s+(with|to)/)
          text.downcase.split(/(?<=with|to)/).first.match(/^\s*(?:[\#]|)(?:[^\w@]+)(?:[^,:@]*(?:\s*)(?:with|to|)){0,1}(?:\s*)/).to_s
        else
          text.downcase.match(/^\s*#[^\W,@]+\s+/).to_s
        end
      end
    end
  end
end
