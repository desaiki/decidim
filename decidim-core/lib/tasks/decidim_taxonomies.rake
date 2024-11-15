# frozen_string_literal: true

require "decidim/maintenance"

namespace :decidim do
  namespace :taxonomies do
    desc "Creates a JSON file with the taxonomies structure imported from older models"
    task :make_plan, [] => :environment do |_task, args|
      Decidim::Organization.find_each do |organization|
        puts "Creating plan for organization #{organization.id} in #{plan_file_path(organization)}"
        FileUtils.mkdir_p(Rails.root.join("tmp/taxonomies"))
        json = planner(organization).to_json do |model|
          puts "...Importing taxonomies from #{model.table_name}"
        end
        File.write(plan_file_path(organization), json)
        puts "Plan created, you can review or edit if needed before importing."
        puts "Import the plan with this command:"
        puts "bin/rails decidim:taxonomies:import_plan[#{plan_file_path(organization)}]"
        puts
      end
    end

    desc "Imports taxonomies and filters structure from a JSON file"
    task :import_plan, [:file] => :environment do |_task, args|
      file = args[:file].to_s
      abort "File not found! [#{file}]" unless File.exist?(file)

      data = JSON.parse(File.read(file))
      organization = Decidim::Organization.find_by(id: data.dig("organization", "id"))
      abort "Organization not found! [#{data["organization"]}]" unless organization

      planner(organization).import(data) do |importer|
        taxonomies = importer.roots
        model = importer.model
        result = importer.result
        puts "...Importing #{taxonomies.count} taxonomies from #{model.table_name}"
        taxonomies.each do |name, taxonomy|
          puts "  - Root taxonomy: #{name}"
          puts "    Taxonomy items: #{taxonomy["taxonomies"].count}"
          puts "    Filters: #{taxonomy["filters"].count}"
          taxonomy["filters"].each do |filter_name, filter|
            puts "     - Filter name: #{filter_name}"
            puts "       Manifest: #{filter["space_manifest"]}"
            puts "       Space filter: #{filter["space_filter"]}"
            puts "       Items: #{filter["items"].count}"
            puts "       Components: #{filter["components"].count}"
          end
        end
        importer.import!
        puts "    Created taxonomies: #{result[:created].count}"
        result[:created].each do |name|
          puts "      - #{name}"
        end
        puts "    Assigned resources: #{result[:assigned].count}"
        result[:assigned].each do |name, resources|
          puts "      - #{name}:"
          resources.each do |object_id|
            puts "        - #{object_id}"
          end
        end
      end
      puts "Taxonomies and filters imported successfully."
    end

    def planner(organization)
      models = [Decidim::Maintenance::ParticipatoryProcessType]
      Decidim::Maintenance::TaxonomyPlan.new(organization, models)
    end

    def plan_file_path(organization)
      Rails.root.join("tmp/taxonomies", "#{organization.host}_plan.json")
    end
  end
end
