# frozen_string_literal: true

module Decidim
  module Surveys
    # This is the engine that runs on the public interface of `Surveys`.
    class AdminEngine < ::Rails::Engine
      isolate_namespace Decidim::Surveys::Admin

      paths["db/migrate"] = nil
      paths["lib/tasks"] = nil

      routes do
        # get "/answer/:session_token", to: "surveys#show", as: :show_survey
        # get "/answer/:session_token/export", to: "surveys#export_response", as: :export_response_survey
        # get "/answers/:id", to: "surveys#index", as: :index_survey
        get "/answer_options", to: "surveys#answer_options", as: :answer_options_survey
        resources :surveys, except: [:new] do
          member do
            get :edit_questions
            patch :update_questions
          end
          resources :answers, only: [:index, :show] do
            member do
              get :export_response
            end
          end
        end
        root to: "surveys#index"
      end

      initializer "decidim_surveys_admin.notifications.components" do
        config.to_prepare do
          Decidim::EventsManager.subscribe(/^decidim\.events\.components/) do |event_name, data|
            CleanSurveyAnswersJob.perform_later(event_name, data)
          end
        end
      end

      def load_seed
        nil
      end
    end
  end
end
