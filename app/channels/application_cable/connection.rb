# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_session

    def connect
      self.current_session = Session.find_by(id: cookies.signed[:session_token])
      reject_unauthorized_connection unless current_session
    end
  end
end
