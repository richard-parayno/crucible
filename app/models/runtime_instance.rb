# frozen_string_literal: true

class RuntimeInstance < ApplicationRecord
  STATUSES = %w[pending starting running unhealthy stopping stopped failed].freeze
  PLACEMENT_KINDS = %w[local_container docker_compose].freeze
  CONTAINER_RUNTIMES = %w[docker podman].freeze

  belongs_to :workspace
  belongs_to :runtime_definition
  has_many :environment_variables, dependent: :destroy
  has_many :runtime_events, dependent: :destroy
  has_many :runtime_artifacts, dependent: :destroy

  before_validation :apply_defaults

  validates :name, presence: true
  validates :status, inclusion: {in: STATUSES}
  validates :placement_kind, inclusion: {in: PLACEMENT_KINDS}
  validates :container_runtime, inclusion: {in: CONTAINER_RUNTIMES}

  delegate :kind, to: :runtime_definition, prefix: :runtime

  def start!
    update!(status: "starting", status_message: nil)
  end

  def running!(external_id:, container_name:)
    update!(
      status: "running",
      external_id:,
      container_name:,
      started_at: Time.current,
      stopped_at: nil,
      last_heartbeat_at: Time.current,
      status_message: nil
    )
  end

  def stopping!
    update!(status: "stopping")
  end

  def stopped!(message = nil)
    update!(status: "stopped", stopped_at: Time.current, status_message: message)
  end

  def unhealthy!(message)
    update!(status: "unhealthy", status_message: message, last_heartbeat_at: Time.current)
  end

  def failed!(message)
    update!(status: "failed", status_message: message, stopped_at: Time.current)
  end

  private

  def apply_defaults
    self.status ||= "pending"
    self.placement_kind ||= "local_container"
    self.container_runtime ||= ContainerEngines.preferred
    self.env ||= {}
    self.config ||= {}
  end
end
