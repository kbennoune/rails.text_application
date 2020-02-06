module RecordMatchers
  class ByString
    def initialize

    end
    class << self
      def match_venues(venues, facebook_places, name_cutoff: 0.7, distance_threshold: 0.5, uniq: false)
        full_matcher = Simhilarity::Matcher.new

        full_matcher.reader = lambda do |obj|
          [obj.geohash, obj.name.to_s].join(' ')
        end

        full_matcher.haystack = facebook_places.find_all{|fp| fp.name && fp.geohash }
        full_results = full_matcher.matches(venues){ |needle, haystack, score| [needle, haystack, score] }

        full_matcher2 = Simhilarity::Matcher.new
        full_matcher2.reader = lambda{|obj| obj.name.to_s }
        full_matcher2.haystack = facebook_places.find_all{|fp| fp.name }
        full_results2 = full_matcher2.matches(venues){ |needle, haystack, score| [needle, haystack, score] }

        full_matcher3 = Simhilarity::Matcher.new
        full_matcher3.reader = lambda{|obj| obj.respond_to?(:street_address) ? [obj.street_address.to_s, obj.name.first(10)].join(' ') : [obj.location_street.to_s, obj.name.first(10)].join(' ') }
        full_matcher3.haystack = facebook_places.find_all{|fp| fp.location_street }
        full_results3 = full_matcher3.matches(venues){ |needle, haystack, score| [needle, haystack, score] }
        all_results = (full_results + full_results2 + full_results3).group_by{|needle, haystack, score| needle.id }.map{|_,v| v.sort_by(&:last).last }
        results = filter_all( score_all(all_results), name_cutoff: name_cutoff, distance_threshold: distance_threshold )

        if uniq
          results.group_by{|_,facebook_place| facebook_place }.map{|k,v| v.sort_by{|_,_,distance| distance}.first }
        else
          results
        end
      end

      def filter_all(collection, name_cutoff:, distance_threshold:)
        collection.find_all{|needle ,haystack, score_distance, full_score, name_score, address_score, weighted_name_score|
          weighted_name_score > name_cutoff && score_distance < distance_threshold
        }
      end

      def score_all(collection)
        address_matcher = Simhilarity::Matcher.new.tap{|m| m.haystack = []}
        name_matcher = Simhilarity::Matcher.new.tap{|m| m.haystack = []}

        collection.map{|needle, haystack, full_score|
          name_score = score(needle.name.to_s, haystack.name.to_s)
          weighted_name_score = weighted_score(needle.name.to_s, haystack.name.to_s, unweighted: name_score, matcher: name_matcher)

          address_score = if needle.street_address.present? && haystack.location_street.present?
            score(needle.street_address, haystack.location_street, matcher: address_matcher )
          else
            nil
          end

          score_distance = distance(full_score, weighted_name_score, address_score )
          [needle, haystack, score_distance, full_score, name_score, address_score, weighted_name_score]
        }
      end

      def weighted_score(str1, str2, unweighted: nil, matcher: Simhilarity::Matcher.new.tap{|m| m.haystack = []})
        unweighted ||= score(str1, str2, matcher: matcher)
        max = max_score(str1, str2, matcher: matcher)
        unweighted > max ? 1.0 : unweighted/max
      end

      def max_score(str1, str2, matcher: Simhilarity::Matcher.new.tap{|m| m.haystack = []})
        nstr1 = matcher.normalize(str1)
        nstr2 = matcher.normalize(str2)
        diff = (nstr1.size - nstr2.size).abs
        smaller, larger = [nstr1,nstr2].sort_by(&:size)
        letters = larger.split('').uniq
        test_str = smaller + diff.times.map{ letters[ SecureRandom.random_number(letters.size) ] }.join('')

        score(smaller, test_str)
      end

      def score(str1, str2, matcher: Simhilarity::Matcher.new.tap{|m| m.haystack = []})
        matcher.score(Simhilarity::Candidate.new(
          Simhilarity::Element.new(matcher,str1),
          Simhilarity::Element.new(matcher,str2)
        ))
      end

      def distance(*distances)
        (distances.compact.sum{|d| (d - 1.0) ** 2} / distances.compact.length.to_f ** 2 ) ** 0.5
      end
    end
  end
end
