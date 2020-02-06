module ChannelTopics
  module ContactInfoHelper
    ADD_WORDS = %w{ add save contact }#[/add/i, /create/i, /contact/i]
    EMAIL_REGEX = %r{[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*}
    # PHONE_REGEX = %r{(?:\+\d{1,2}\s)?\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}}
    PHONE_REGEX = %r{(?:[^a-zA-Z\d\s]*\d[\W\s]*){10,15}}
    WORD_BREAK_PUNCTUATION = '\p{Ps}\p{Pe}\p{Pi}\p{Pf}\p{Po}'
    GROUP_LINE_REGEX = /(?<!\w)[Tt]o (?:(?:(?:[^#{ WORD_BREAK_PUNCTUATION }]*)[\W]*(?:[#{ WORD_BREAK_PUNCTUATION }] |[#{ WORD_BREAK_PUNCTUATION }]|$))+)$/
    GROUP_REGEX = Regexp.new(GROUP_LINE_REGEX.to_s.gsub(/(\?\:|\?-mix\:)/, ''))

    def contact_info_from_text
      emails = message_text.scan(ChannelTopics::ContactInfoHelper::EMAIL_REGEX)
      numbers = message_text.scan(ChannelTopics::ContactInfoHelper::PHONE_REGEX)
      group_lines = message_text.scan(ChannelTopics::ContactInfoHelper::GROUP_LINE_REGEX)
      rest_of_text = [emails,numbers,group_lines].flatten.inject(message_text){|acc, sub|  acc.gsub(sub,'') }
      add_words_or_expr = ADD_WORDS.map{|w| "(?<!\w)[#{w[0].upcase}#{w[0]}]#{w[1..-1]}"}.join('|')

      names = rest_of_text.scan(/(?:#{add_words_or_expr})[\s^\W]*(?:\n|)([^\n]*)/).flatten.map{|name| name.gsub(Regexp.new(add_words_or_expr),'')}
      group_names = group_lines.join.gsub(' and ',', ').match( GROUP_REGEX ).try(:[], 2).to_s.split(/[#{ WORD_BREAK_PUNCTUATION }]/).map(&:strip)

      { mobile: numbers[0], email: emails[0], name: names[0].try(:strip), group_names: group_names }.compact
    end
  end
end
