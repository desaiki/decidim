# frozen_string_literal: true

require "spec_helper"

describe Decidim::Debates::Admin::UpdateDebate do
  subject { described_class.new(form, debate) }

  let(:debate) { create(:debate) }
  let(:organization) { debate.component.organization }
  let(:user) { create(:user, :admin, :confirmed, organization:) }
  let(:taxonomizations) do
    2.times.map { build(:taxonomization, taxonomy: create(:taxonomy, :with_parent, organization:), taxonomizable: nil) }
  end
  let(:form) do
    double(
      invalid?: invalid,
      current_user: user,
      title: { en: "title" },
      description: { en: "description" },
      information_updates: { en: "information_updates" },
      instructions: { en: "instructions" },
      start_time: 1.day.from_now,
      end_time: 1.day.from_now + 1.hour,
      taxonomizations:,
      current_organization: organization,
      comments_enabled: true
    )
  end
  let(:invalid) { false }

  context "when the form is not valid" do
    let(:invalid) { true }

    it "is not valid" do
      expect { subject.call }.to broadcast(:invalid)
    end
  end

  context "when everything is ok" do
    it "updates the debate" do
      subject.call
      expect(translated(debate.title)).to eq "title"
      expect(translated(debate.description)).to eq "description"
      expect(translated(debate.information_updates)).to eq "information_updates"
      expect(translated(debate.instructions)).to eq "instructions"
    end

    it "sets the taxonomies" do
      subject.call
      expect(debate.reload.taxonomies).to match_array(taxonomizations.map(&:taxonomy))
    end

    it "traces the action", versioning: true do
      expect(Decidim.traceability)
        .to receive(:update!)
        .with(debate, user, hash_including(:taxonomizations, :title, :description, :information_updates, :instructions, :end_time, :start_time))
        .and_call_original

      expect { subject.call }.to change(Decidim::ActionLog, :count)
      action_log = Decidim::ActionLog.last
      expect(action_log.version).to be_present
      expect(action_log.version.event).to eq "update"
    end
  end
end
