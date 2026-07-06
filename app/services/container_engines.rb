# frozen_string_literal: true

class ContainerEngines
  ENGINES = %w[docker podman].freeze

  class << self
    def available
      ENGINES.select { |engine| system("command", "-v", engine, out: File::NULL, err: File::NULL) }
    end

    def preferred
      available.first || "docker"
    end
  end
end
