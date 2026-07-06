# frozen_string_literal: true

class RuntimeEvent < ApplicationRecord
  LEVELS = %w[debug info warn error].freeze

  belongs_to :runtime_instance

  before_validation :apply_defaults

  validates :level, inclusion: {in: LEVELS}
  validates :message, :occurred_at, presence: true

  after_create_commit :broadcast_to_workspace

  private

  def broadcast_to_workspace
    RuntimeInstancesChannel.broadcast_to(
      runtime_instance.workspace,
      {
        type: "runtime_event",
        runtime_instance_id: runtime_instance_id,
        event: RuntimeInstanceSerializer.event(self),
        instance: RuntimeInstanceSerializer.instance(runtime_instance)
      }
    )
  end

  def apply_defaults
    self.level ||= "info"
    self.metadata ||= {}
    self.occurred_at ||= Time.current
  end
end
