# frozen_string_literal: true

require "spec_helper"

module Decidim::Meetings
  describe CloseMeetingReminderGenerator do
    subject { described_class.new }

    let(:manifest) do
      double(
        settings: double(
          attributes: {
            reminder_times: double(default: intervals)
          }
        )
      )
    end
    let(:intervals) { [3.days, 7.days] }
    let(:organization) { create(:organization) }
    let(:participatory_space) { create(:participatory_process, organization:) }
    let!(:component) { create(:component, :published, manifest_name: "meetings", participatory_space:) }
    let(:user) { create(:user, :admin, organization:, email: "user@example.org") }
    let!(:meeting) { create(:meeting, :published, component:, author: user, start_time:, end_time:, closed_at:) }
    let(:closed_at) { nil }

    before do
      allow(Decidim.reminders_registry).to receive(:for).with(:close_meeting).and_return(manifest)
    end

    describe "#generate" do
      context "when there is a past meeting without a report in the last 3 days" do
        let(:start_time) { 4.days.ago }
        let(:end_time) { 3.days.ago }

        context "and the meeting is closed" do
          let(:closed_at) { 2.days.ago }

          it "does not send the reminder" do
            expect(Decidim::Meetings::SendCloseMeetingReminderJob).not_to receive(:perform_later)

            expect { subject.generate }.not_to change(Decidim::Reminder, :count)
          end
        end

        context "and the user meeting is not closed" do
          it "sends reminder" do
            expect(Decidim::Meetings::SendCloseMeetingReminderJob).to receive(:perform_later)

            expect { subject.generate }.to change(Decidim::Reminder, :count).by(1)
          end
        end

        context "and the official meeting is not closed" do
          let(:other_organization) { create(:organization) }
          let!(:user) { create(:user, :admin, organization:, email: "user@example.org") }
          let!(:other_admin) { create(:user, :admin, organization: other_organization, email: "user@example.org") }
          let!(:meeting) { create(:meeting, :published, :official, component:, start_time:, end_time:, closed_at:) }

          it "sends reminder" do
            expect(Decidim::Meetings::SendCloseMeetingReminderJob).to receive(:perform_later)

            expect { subject.generate }.to change(Decidim::Reminder, :count).by(1)
          end

          context "and there are space admins" do
            context "and space admin is Participatory Process" do
              let(:participatory_space) { create(:participatory_process, organization:) }
              let!(:process_admin) { create(:process_admin, participatory_process: participatory_space) }

              it "sends reminder" do
                expect(Decidim::Meetings::SendCloseMeetingReminderJob).to receive(:perform_later).twice

                expect { subject.generate }.to change(Decidim::Reminder, :count).by(2)
              end
            end

            context "and space admin is Assembly" do
              let(:participatory_space) { create(:assembly, organization:) }
              let!(:process_admin) { create(:assembly_admin, assembly: participatory_space) }

              it "sends reminder" do
                expect(Decidim::Meetings::SendCloseMeetingReminderJob).to receive(:perform_later).twice

                expect { subject.generate }.to change(Decidim::Reminder, :count).by(2)
              end
            end
          end
        end
      end

      context "when there is a past meeting without a report in the last 7 days" do
        let(:start_time) { 8.days.ago }
        let(:end_time) { 7.days.ago }

        context "when the meeting is closed" do
          let(:closed_at) { 2.days.ago }

          it "does not send the reminder" do
            expect(Decidim::Meetings::SendCloseMeetingReminderJob).not_to receive(:perform_later)

            expect { subject.generate }.not_to change(Decidim::Reminder, :count)
            expect(Decidim::Reminder.first).to be_nil
          end
        end

        context "when the meeting is not closed" do
          it "sends reminder" do
            expect(Decidim::Meetings::SendCloseMeetingReminderJob).to receive(:perform_later)

            expect { subject.generate }.to change(Decidim::Reminder, :count).by(1)
            expect(Decidim::Reminder.first.records.count).to eq(1)
          end
        end
      end

      context "when the meeting is in the past but end date does not correspond to the interval" do
        let(:start_time) { 10.days.ago }
        let(:end_time) { 9.days.ago }

        it "does not send the reminder" do
          expect(Decidim::Meetings::SendCloseMeetingReminderJob).not_to receive(:perform_later)

          expect { subject.generate }.not_to change(Decidim::Reminder, :count)
          expect(Decidim::Reminder.first).to be_nil
        end
      end

      context "when the reminder exists" do
        let!(:reminder) { create(:reminder, user:, component:) }
        let(:start_time) { 4.days.ago }
        let(:end_time) { 3.days.ago }

        it "sends existing reminder" do
          expect(Decidim::Meetings::SendCloseMeetingReminderJob).to receive(:perform_later)

          expect { subject.generate }.not_to change(Decidim::Reminder, :count)
        end
      end
    end
  end
end
