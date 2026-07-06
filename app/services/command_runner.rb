# frozen_string_literal: true

require "open3"

class CommandRunner
  Result = Data.define(:stdout, :stderr, :status) do
    def success?
      status.success?
    end
  end

  def call(*argv)
    stdout, stderr, status = Open3.capture3(*argv)
    Result.new(stdout:, stderr:, status:)
  end
end
