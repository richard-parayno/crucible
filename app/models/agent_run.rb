# frozen_string_literal: true

class AgentRun < ApplicationRecord
  STATUSES = %w[queued running succeeded failed canceled].freeze

  belongs_to :runtime_instance

  before_validation :apply_defaults

  validates :command, presence: true
  validates :status, inclusion: {in: STATUSES}

  delegate :workspace, to: :runtime_instance

  def running!
    update!(status: "running", started_at: Time.current, finished_at: nil, status_message: nil)
  end

  def succeeded!(exit_code:, output:)
    update!(
      status: "succeeded",
      exit_code:,
      output:,
      finished_at: Time.current,
      status_message: "Command completed successfully."
    )
  end

  def failed!(message, exit_code: nil, output: self.output)
    update!(
      status: "failed",
      exit_code:,
      output:,
      finished_at: Time.current,
      status_message: message
    )
  end

  private

  def apply_defaults
    self.status ||= "queued"
  end
end
