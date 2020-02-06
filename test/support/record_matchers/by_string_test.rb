require 'test_helper'

class ByStringTest < ActiveSupport::TestCase

  test 'matching ticketmaster_venues and places' do
    ticketmaster_venues_subset = ticketmaster_venues
    matches = RecordMatchers::ByString.match_venues(ticketmaster_venues_subset, facebook_places)
    mariott_match = matches.find{|ticketmaster_venue,place| ticketmaster_venue.name.match(/[Mm]arriott/) }
    assert_match /[Mm]arriott/, mariott_match[1].name
    # Several of these scores are based on
    # random metrics so they might fluctuate!

    # check that weighted score is close to 1
    assert_in_delta(mariott_match.last, 1.0, 0.2)
    # check that distance is small
    assert_in_delta(mariott_match[2], 0.0, 0.1)
    #check that overall score is high
    assert_in_delta(mariott_match[3], 0.95, 0.02)

    dpac_match = matches.find{|v,_| v.name.match(/DPAC/) }

    assert_match /DPAC/, dpac_match[1].name
    assert_equal 20, matches.size
  end

  test 'matching ticketmaster_venues and places uniquely' do
    ticketmaster_venues_subset = ticketmaster_venues
    facebook_places_subset = facebook_places.find_all{|fp| fp.geohash.match(/^dnru/)}
    matches = RecordMatchers::ByString.match_venues(ticketmaster_venues_subset, facebook_places_subset, uniq: true)
    assert_nil matches.find{|v,_| v.name == 'Carolina Theatre Cinema' }
    assert matches.find{|v,_| v.name.match('Carolina Theatre') }

    assert_equal 19, matches.size
  end

  def ticketmaster_venues
    structs(*YAML.load( File.read(data_dir.join('ticketmaster_venues.yml')) ).values)
  end

  def facebook_places
    structs(*YAML.load( File.read(data_dir.join('facebook_places.yml')) ).values)
  end

  def data_dir
    Rails.root.join('test','test_data')
  end

  def structs(*attributes)
    attributes.each_with_index.map do |attr, idx|
      OpenStruct.new(attr.merge(id: idx + 1))
    end
  end
end
