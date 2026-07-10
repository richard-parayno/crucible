# frozen_string_literal: true

class ExecutablePathLookup
  def initialize(path: ENV.fetch("PATH", ""))
    @paths = path.split(File::PATH_SEPARATOR)
  end

  def call(command)
    paths.each do |path|
      executable_path = File.join(path, command)
      return executable_path if File.file?(executable_path) && File.executable?(executable_path)
    end

    nil
  end

  private

  attr_reader :paths
end
