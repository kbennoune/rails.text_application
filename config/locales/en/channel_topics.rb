person_add = { en: { channel_topics: { person: { add: {
  failed: {
    contact_file: proc{|_,params|  "We couldn't figure out the person's details from the contact. Can you text support at #{params[:support_number]}?" },
    text: proc{|_,params| "We couldn't get the person's information from the text. Can you make sure that there is a name and phone number included?" }
  }
} } } } }

[
  person_add,
  # unknown_unregistered
].inject({}){|acc, hsh| acc.deep_merge(hsh) }
