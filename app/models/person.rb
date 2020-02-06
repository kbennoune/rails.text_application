class Person < ApplicationRecord
  belongs_to :user, optional: true
  has_many :channel_people

  has_many :text_group_people
  has_many :text_groups, through: :text_group_people
  has_many :service_invitations, inverse_of: :invited_person, foreign_key: :invited_person_id

  has_many :real_person_aliases, foreign_key: :alias_id, class_name: 'PersonAlias', inverse_of: :alias
  has_many :alias_person_aliases, foreign_key: :real_id, class_name: 'PersonAlias', inverse_of: :real
  has_many :real_people, through: :real_person_aliases, class_name: self.name, source: :real
  has_many :aliases, through: :alias_person_aliases, class_name: self.name, source: :alias

  has_many :active_real_person_aliases, ->{ where({status: ::PersonAlias::STATUS_LISTEN }) }, foreign_key: :alias_id, class_name: 'PersonAlias', inverse_of: :alias
  has_many :active_real_people, through: :active_real_person_aliases, class_name: self.name, source: :real

  has_many :inactive_real_person_aliases, ->{ where({status: ::PersonAlias::STATUS_SLEEP }) }, foreign_key: :alias_id, class_name: 'PersonAlias', inverse_of: :alias
  has_many :inactive_real_people, through: :inactive_real_person_aliases, class_name: self.name, source: :real

  has_many :person_subscriptions
  has_many :subscriptions, through: :person_subscriptions

  has_many :channels, ->{ distinct }, through: :channel_people do
    def unique_push(*records, &finder)
      Person.transaction do
        records.flatten.find_all do |record|
          begin
            self.push record
          rescue ActiveRecord::RecordNotUnique => e
            finder.present? ? finder.call(record) : false
          end
        end
      end
    end
  end

  attribute :mobile, :phone_number

  attribute :preferred_language, :string, default: 'en'

  fuzzily_searchable :name, async: true

  def display_name
    name
  end

  def preferred_locale
    preferred_language.to_sym
  end

  def mention_code(within:, fuzzy_match_cutoff: 0.3)
    channel = within
    names = display_name.downcase.split(' ')
    short_name = if names.size == 1
      display_name.gsub("\s",'').downcase
    else
      [ names.first,[names.first, names.last.last].join(''),[names.first.first, names.last].join('') ].find{ |candidate|
        match = Trigram.channel_matches_for(channel, candidate ).where( owner_type: self.class.name ).first
        match && match.owner_id == self.id && (match.matches.to_f/match.score.to_f > fuzzy_match_cutoff)
      } || display_name.gsub("\s",'').downcase
    end

    "@#{short_name}"
  end
end
