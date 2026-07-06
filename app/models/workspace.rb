# frozen_string_literal: true

class Workspace < ApplicationRecord
  belongs_to :user
  has_many :runtime_instances, dependent: :destroy

  validates :name, presence: true
end
