# frozen_string_literal: true

class RuntimeDefinition < ApplicationRecord
  KINDS = %w[codex claude opencode openclaw hermes custom].freeze

  has_many :runtime_instances, dependent: :restrict_with_exception

  before_validation :apply_defaults

  validates :kind, presence: true, inclusion: {in: KINDS}, uniqueness: true
  validates :name, :container_image, :default_command, presence: true

  scope :active, -> { where(active: true).order(:name) }

  private

  def apply_defaults
    self.default_env ||= {}
    self.config_schema ||= {}
    self.active = true if active.nil?
  end
end
