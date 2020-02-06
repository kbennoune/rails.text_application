module DataApi
  module ControllerTestHelper

    def authentication_header( person )
      { 'HTTP_AUTHORIZATION' => 'Bearer ' + ApiRequest::JsonToken.encode(payload: {person_id: person.id}, expires_in: 10.minutes)}
    end
    
  end
end
