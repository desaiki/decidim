# frozen_string_literal: true

module Decidim
  module Core
    class OrganizationType < Decidim::Api::Types::BaseObject
      description "The current organization"

      field :name, Decidim::Core::TranslatedFieldType, "The name of the current organization", null: true

      field :stats, [Core::StatisticType, { null: true }], description: "The statistics associated to this object", null: true

      def stats
        Decidim.stats.with_context(object)
      end

      def name
        object.org_translated_name
      end
    end
  end
end
