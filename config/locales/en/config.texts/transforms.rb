{
  'channel_topics.group.list.list' => { groups_and_number_links: proc{|_,params| params[:groups].map{|group|
     "%{group}\nsms:%{phone_number}?body=%{encoded_body}" % {group: group.titleize, phone_number: params[:root_phone_number], encoded_body: URI.encode("#chat #{group}")}
   }.join("\n\n")}}
}
