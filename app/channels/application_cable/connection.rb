module ApplicationCable
  class Connection < ActionCable::Connection::Base
    def connect
      @session_user_id = cookies.encrypted[:user_id]
      @session_user = User.find_by(id: @session_user_id) if @session_user_id
      # same session version check as ApplicationController#validate_session_user!
      reject_unauthorized_connection unless @session_user && @session_user.session_version == cookies.encrypted[:session_version].to_i
    end
  end
end
