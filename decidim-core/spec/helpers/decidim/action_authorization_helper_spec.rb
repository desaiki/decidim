# frozen_string_literal: true

require "spec_helper"

module Decidim
  describe ActionAuthorizationHelper do
    let(:component) { create(:component) }
    let(:resource) { nil }
    let(:permissions_holder) { nil }
    let(:user) { create(:user) }
    let(:action) { "foo" }
    let(:status) { double(ok?: authorized, pending_authorizations_count:, global_code:) }
    let(:authorized) { true }
    let(:pending_authorizations_count) { 0 }
    let(:global_code) { :ok }

    let(:widget_text) { "Act" }
    let(:path) { "fake_path" }
    let(:path_as_action_or_href) { /(action|href)="#{path}"/ }
    let(:verification_required_widget_text) { "Verify your account to act" }

    before do
      allow(helper).to receive(:current_component).and_return(component)
      allow(helper).to receive(:current_user).and_return(user)
      allow(helper).to receive(:action_authorized_to).with(action, resource:, permissions_holder:).and_return(status)
      allow(helper).to receive(:action_authorized_to).with(action, resource:, permissions_holder: component).and_return(status)
    end

    shared_examples "an action authorization widget helper" do |params|
      if params[:has_action]
        context "when the action authorization is not completed" do
          let(:authorized) { false }
          let(:global_code) { false }

          if params[:with_automatic_authorization_required_message]
            it "wraps the action with an authorization required message" do
              expect(subject).not_to include(widget_text)
              expect(subject).to include(verification_required_widget_text)
            end
          else
            it "does not wrap the action with an authorization required message" do
              expect(subject).to include(widget_text)
              expect(subject).not_to include(verification_required_widget_text)
            end
          end

          context "and there is only an authorization related to the action" do
            let(:pending_authorizations_count) { 1 }

            it "renders a widget toggling the authorization modal" do
              expect(subject).not_to match(path_as_action_or_href)
              expect(subject).to include('data-dialog-open="authorizationModal"')
              expect(subject).to include("data-dialog-remote-url=\"/authorization_modals/#{action}/f/#{component.id}\"")
              expect(subject).to include(*params[:widget_parts])
            end

            context "when called with a resource" do
              let(:resource) { create(:dummy_resource, component:) }

              it "renders a widget toggling the authorization modal" do
                expect(subject).not_to match(path_as_action_or_href)
                expect(subject).to include('data-dialog-open="authorizationModal"')
                expect(subject).to include("data-dialog-remote-url=\"/authorization_modals/#{action}/f/#{component.id}/#{resource.resource_manifest.name}/#{resource.id}\"")
                expect(subject).to include(*params[:widget_parts])
              end
            end

            context "when called with no component and permissions_holder" do
              let(:component) { nil }
              let(:resource) { create(:dummy_resource) }
              let(:permissions_holder) { resource }

              it "renders a widget toggling the authorization modal of free resources not related with a component" do
                expect(subject).not_to match(path_as_action_or_href)
                expect(subject).to include('data-dialog-open="authorizationModal"')
                expect(subject).to include("data-dialog-remote-url=\"/free_resource_authorization_modals/#{action}/f/#{resource.resource_manifest.name}/#{resource.id}\"")
                expect(subject).to include(*params[:widget_parts])
              end
            end
          end

          context "and there are more than one authorizations related to the action" do
            let(:pending_authorizations_count) { 2 }

            it "renders a link to renew onboarding data including the pending action info in data attributes" do
              expect(subject).not_to match(path_as_action_or_href)
              expect(subject).not_to include('data-dialog-open="authorizationModal"')
              expect(subject).to include('href="/authorizations/renew_onboarding_data"')
              expect(subject).to include("data-onboarding-permissions-holder=\"#{component.to_gid}\"")
              expect(subject).to include("data-onboarding-action=\"#{action}\"")
              expect(subject).to include("data-onboarding-redirect-path=\"#{path}\"")
              expect(subject).to match(/\A<a /)
            end

            context "when called with a resource" do
              let(:resource) { create(:dummy_resource, component:) }

              it "renders a link to renew onboarding data including the pending action info in data attributes" do
                expect(subject).not_to match(path_as_action_or_href)
                expect(subject).not_to include('data-dialog-open="authorizationModal"')
                expect(subject).to include('href="/authorizations/renew_onboarding_data"')
                expect(subject).to include("data-onboarding-model=\"#{resource.to_gid}\"")
                expect(subject).not_to include("data-onboarding-permissions-holder=\"#{component.to_gid}\"")
                expect(subject).to include("data-onboarding-action=\"#{action}\"")
                expect(subject).to include("data-onboarding-redirect-path=\"#{path}\"")
                expect(subject).to match(/\A<a /)
              end
            end

            context "when called with no component and permissions_holder" do
              let(:component) { nil }
              let(:resource) { create(:dummy_resource) }
              let(:permissions_holder) { resource }

              it "renders a widget renewing onboarding data and redirecting to the pending action onboarding page including permissions holder data" do
                expect(subject).not_to match(path_as_action_or_href)
                expect(subject).not_to include('data-dialog-open="authorizationModal"')
                expect(subject).to include('href="/authorizations/renew_onboarding_data"')
                expect(subject).to include("data-onboarding-model=\"#{resource.to_gid}\"")
                expect(subject).to include("data-onboarding-permissions-holder=\"#{resource.to_gid}\"")
                expect(subject).to include("data-onboarding-action=\"#{action}\"")
                expect(subject).to include("data-onboarding-redirect-path=\"#{path}\"")
                expect(subject).to match(/\A<a /)
              end
            end
          end
        end

      else
        let(:action) { nil }
      end

      context "when #{params[:has_action] ? "the action is authorized" : "the user is logged"}" do
        it "renders a regular widget" do
          expect(subject).not_to include("data-dialog-open")
          expect(subject).to match(path_as_action_or_href)
          expect(subject).to include(*params[:widget_parts])
        end
      end

      context "when there is not a logged user" do
        let(:user) { nil }

        it "renders a widget toggling the login modal" do
          expect(subject).not_to match(path_as_action_or_href)
          expect(subject).to include('data-dialog-open="loginModal"')
          expect(subject).to include(*params[:widget_parts])
        end
      end
    end

    describe "action_authorized_link_to" do
      context "when called with text" do
        subject(:rendered) { helper.action_authorized_link_to(action, widget_text, path, resource:, permissions_holder:) }

        it_behaves_like "an action authorization widget helper", has_action: true, widget_parts: %w(<a), with_automatic_authorization_required_message: true
      end

      context "when called with a block" do
        subject(:rendered) { helper.action_authorized_link_to(action, path, resource:, permissions_holder:) { widget_text } }

        it_behaves_like "an action authorization widget helper", has_action: true, widget_parts: %w(<a), with_automatic_authorization_required_message: false
      end
    end

    describe "action_authorized_button_to" do
      context "when called with text" do
        subject(:rendered) { helper.action_authorized_button_to(action, widget_text, path, resource:, permissions_holder:) }

        it_behaves_like "an action authorization widget helper", has_action: true, widget_parts: %w(<input type="submit"), with_automatic_authorization_required_message: true
      end

      context "when called with a block" do
        subject(:rendered) { helper.action_authorized_button_to(action, path, resource:, permissions_holder:) { widget_text } }

        it_behaves_like "an action authorization widget helper", has_action: true, widget_parts: %w(<input type="submit"), with_automatic_authorization_required_message: false
      end
    end

    describe "logged_link_to" do
      context "when called with text" do
        subject(:rendered) { helper.logged_link_to(widget_text, path, resource:) }

        it_behaves_like "an action authorization widget helper", has_action: false, widget_parts: %w(<a), with_automatic_authorization_required_message: false
      end

      context "when called with a block" do
        subject(:rendered) { helper.logged_link_to(path, resource:) { widget_text } }

        it_behaves_like "an action authorization widget helper", has_action: false, widget_parts: %w(<a), with_automatic_authorization_required_message: false
      end
    end

    describe "logged_button_to" do
      context "when called with text" do
        subject(:rendered) { helper.logged_button_to(widget_text, path, resource:) }

        it_behaves_like "an action authorization widget helper", has_action: false, widget_parts: %w(<input type="submit"), with_automatic_authorization_required_message: false
      end

      context "when called with a block" do
        subject(:rendered) { helper.logged_button_to(path, resource:) { widget_text } }

        it_behaves_like "an action authorization widget helper", has_action: false, widget_parts: %w(<input type="submit"), with_automatic_authorization_required_message: false
      end
    end
  end
end
