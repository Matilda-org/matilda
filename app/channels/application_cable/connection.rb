module ApplicationCable
  class Connection < ActionCable::Connection::Base
    def connect
      @session_user_id = cookies.encrypted[:user_id]
      reject_unauthorized_connection unless @session_user_id && @session_user = User.find_by(id: @session_user_id)
    end
  end
end
