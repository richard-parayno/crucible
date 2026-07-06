# frozen_string_literal: true

module PlacementDrivers
  class UnknownDriver < StandardError; end

  def self.for(kind)
    case kind
    when "local_container"
      LocalContainer.new
    else
      raise UnknownDriver, "Unknown placement driver: #{kind}"
    end
  end
end
