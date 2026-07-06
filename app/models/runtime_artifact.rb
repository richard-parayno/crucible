# frozen_string_literal: true

class RuntimeArtifact < ApplicationRecord
  belongs_to :runtime_instance

  before_validation :apply_defaults

  validates :kind, :path, presence: true

  private

  def apply_defaults
    self.kind ||= "file"
    self.metadata ||= {}
  end
end
