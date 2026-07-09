# frozen_string_literal: true

class EnvironmentVariable < ApplicationRecord
  SYSTEM_SCOPE = "system"
  RUNTIME_INSTANCE_SCOPE = "runtime_instance"
  SCOPES = [SYSTEM_SCOPE, RUNTIME_INSTANCE_SCOPE].freeze
  KEY_FORMAT = /\A[A-Z_][A-Z0-9_]*\z/
  MASKED_VALUE = "********"

  belongs_to :runtime_instance, optional: true

  encrypts :value

  before_validation :apply_defaults
  before_validation :normalize_key

  scope :enabled, -> { where(enabled: true) }
  scope :system_variables, -> { where(scope: SYSTEM_SCOPE, runtime_instance_id: nil) }
  scope :runtime_instance_variables, ->(runtime_instance) {
    where(scope: RUNTIME_INSTANCE_SCOPE, runtime_instance:)
  }

  validates :scope, presence: true, inclusion: {in: SCOPES}
  validates :key, presence: true, format: {with: KEY_FORMAT}
  validates :sensitive, inclusion: {in: [true, false]}
  validates :enabled, inclusion: {in: [true, false]}

  validate :value_is_not_nil
  validate :scope_matches_runtime_instance
  validate :key_is_unique_within_scope

  def system_scope?
    scope == SYSTEM_SCOPE
  end

  def runtime_instance_scope?
    scope == RUNTIME_INSTANCE_SCOPE
  end

  def safe_attributes
    {
      id:,
      scope:,
      key:,
      value: sensitive? ? MASKED_VALUE : value,
      sensitive:,
      enabled:,
      runtime_instance_id:,
      value_present: !value.nil?,
      created_at: created_at&.iso8601,
      updated_at: updated_at&.iso8601
    }
  end

  private

  def apply_defaults
    self.scope ||= SYSTEM_SCOPE
    self.sensitive = false if sensitive.nil?
    self.enabled = true if enabled.nil?
  end

  def normalize_key
    self.key = key.to_s.strip if key.present?
  end

  def value_is_not_nil
    errors.add(:value, "can't be nil") if value.nil?
  end

  def scope_matches_runtime_instance
    return if scope.blank?

    if system_scope? && runtime_instance_attached?
      errors.add(:runtime_instance, "must be blank for system variables")
    elsif runtime_instance_scope? && !runtime_instance_attached?
      errors.add(:runtime_instance, "must be present for runtime variables")
    end
  end

  def key_is_unique_within_scope
    return if key.blank? || scope.blank?

    relation = self.class.where(scope:, key:)
    relation = relation.where.not(id:) if persisted?

    relation =
      if system_scope?
        relation.where(runtime_instance_id: nil)
      elsif runtime_instance_scope?
        relation.where(runtime_instance_id:)
      else
        return
      end

    errors.add(:key, "has already been taken") if relation.exists?
  end

  def runtime_instance_attached?
    runtime_instance_id.present? || runtime_instance.present?
  end
end
