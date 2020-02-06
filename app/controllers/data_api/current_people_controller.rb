module DataApi
  class CurrentPeopleController < BaseController

    def show
      render json: { current_person: current_person.slice( :id, :name, :mobile, :timezone, :email ) }
    end
  end
end
