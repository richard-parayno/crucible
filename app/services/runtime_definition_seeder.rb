# frozen_string_literal: true

class RuntimeDefinitionSeeder
  DEFINITIONS = AgentCatalog.runtime_definitions.freeze

  def self.call
    DEFINITIONS.each do |attributes|
      RuntimeDefinition.find_or_initialize_by(kind: attributes[:kind]).tap do |runtime_definition|
        runtime_definition.assign_attributes(attributes)
        runtime_definition.save!
      end
    end
  end
end
