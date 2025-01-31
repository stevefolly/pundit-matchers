# frozen_string_literal: true

RSpec.describe Pundit::Matchers::PermitActionsMatcher do
  it_behaves_like 'an actions matcher'

  describe '#description' do
    subject { described_class.new(:test).description }

    it { is_expected.to eq 'permit [:test]' }
  end

  describe '#matches?' do
    subject { matcher.matches?(policy) }

    let(:matcher) { described_class.new(:test1, :test2) }

    it_behaves_like 'a matcher that checks actions'

    context 'when all expected actions are forbidden' do
      let(:policy) { policy_factory(test1?: false, test2?: false) }

      it { is_expected.to be false }
    end

    context 'when some expected actions are forbidden' do
      let(:policy) { policy_factory(test1?: true, test2?: false) }

      it { is_expected.to be false }
    end

    context 'when all expected actions are permitted' do
      let(:policy) { policy_factory(test1?: true, test2?: true) }

      it { is_expected.to be true }
    end
  end

  describe '#does_not_match?' do
    subject { matcher.does_not_match?(policy) }

    let(:matcher) { described_class.new(:test1, :test2) }

    it_behaves_like 'a matcher that checks actions'

    context 'when all expected actions are forbidden' do
      let(:policy) { policy_factory(test1?: false, test2?: false) }

      it { is_expected.to be true }
    end

    context 'when some expected actions are forbidden' do
      let(:policy) { policy_factory(test1?: true, test2?: false) }

      it { is_expected.to be false }
    end

    context 'when all expected actions are permitted' do
      let(:policy) { policy_factory(test1?: true, test2?: true) }

      it { is_expected.to be false }
    end
  end

  describe '#failure_message' do
    subject { matcher.failure_message }

    let(:matcher) { described_class.new(:test) }
    let(:policy) { policy_factory(test?: false) }

    before do
      matcher.matches?(policy)
    end

    it { is_expected.to eq "expected 'TestPolicy' to permit [:test], but forbade [:test] for 'user'" }
  end

  describe '#failure_message_when_negated' do
    subject { matcher.failure_message_when_negated }

    let(:matcher) { described_class.new(:test) }
    let(:policy) { policy_factory(test?: true) }

    before do
      matcher.does_not_match?(policy)
    end

    it { is_expected.to eq "expected 'TestPolicy' to forbid [:test], but permitted [:test] for 'user'" }
  end

  describe 'RSpec integration' do
    subject(:policy) { policy_factory }

    let(:failure_message) do
      "expected 'TestPolicy' to permit [:test], but forbade [:test] for 'user'"
    end

    let(:failure_message_when_negated) do
      "expected 'TestPolicy' to forbid [:test], but permitted [:test] for 'user'"
    end

    context 'when policy has dynamic action' do
      subject(:policy) { DynamicTestPolicy.new }

      it { is_expected.to permit_actions(:poke) }
    end

    it 'supports composability' do
      policy = policy_factory(test1?: true, test2?: false)

      expect(policy)
        .to permit_actions(:test1)
        .and forbid_actions(:test2)
    end

    context 'when expectation is met' do
      subject(:policy) { policy_factory(test?: true) }

      it { is_expected.to permit_actions(:test) }
      it { is_expected.not_to forbid_actions(:test) }

      it 'provides a user friendly failure message' do
        expect do
          expect(policy).to forbid_actions(:test)
        end.to fail_with(failure_message_when_negated)
      end

      it 'provides a user friendly negated failure message' do
        expect do
          expect(policy).not_to permit_actions(:test)
        end.to fail_with(failure_message_when_negated)
      end
    end

    context 'with a single action matcher' do
      subject(:policy) { policy_factory(test?: true, test2?: true) }

      it 'ensures that it has been called with a single action' do
        expect do
          expect(policy).to permit_action(%i[test test2])
        end.to raise_error ArgumentError, described_class::ONE_ARGUMENT_REQUIRED_ERROR
      end
    end

    context 'when expectation is not met' do
      subject(:policy) { policy_factory(test?: false) }

      it { is_expected.not_to permit_actions(:test) }
      it { is_expected.to forbid_actions(:test) }

      it 'provides a user friendly failure message' do
        expect do
          expect(policy).to permit_actions(:test)
        end.to fail_with(failure_message)
      end

      it 'provides a user friendly negated failure message' do
        expect do
          expect(policy).not_to forbid_actions(:test)
        end.to fail_with(failure_message)
      end
    end

    describe 'single action matcher' do
      let(:test_matcher) { instance_double(described_class, matches?: true, ensure_single_action!: nil) }

      before do
        allow(described_class).to receive(:new).and_return(test_matcher)
        allow(test_matcher).to receive(:ensure_single_action!).and_return(test_matcher)
      end

      it 'defines permit_action matcher' do
        expect(policy).to permit_action(:test)

        expect(described_class).to have_received(:new).with(:test)
      end

      it 'ensures that it has been called with a single action' do
        expect(policy).to permit_action(:test)

        expect(test_matcher).to have_received(:ensure_single_action!)
      end
    end

    describe 'single action negated matcher' do
      let(:test_matcher) { instance_double(described_class, does_not_match?: true, ensure_single_action!: nil) }

      before do
        allow(described_class).to receive(:new).and_return(test_matcher)
        allow(test_matcher).to receive(:ensure_single_action!).and_return(test_matcher)
      end

      it 'defines forbid_action matcher' do
        expect(policy).to forbid_action(:test)

        expect(described_class).to have_received(:new).with(:test)
      end

      it 'ensures that it has been called with a single action' do
        expect(policy).to forbid_action(:test)

        expect(test_matcher).to have_received(:ensure_single_action!)
      end
    end

    describe 'helper matchers' do
      let(:test_matcher) { instance_double(described_class, matches?: true) }

      before do
        allow(described_class).to receive(:new).and_return(test_matcher)
      end

      it 'defines permit_new_and_create_actions matcher' do
        expect(policy).to permit_new_and_create_actions

        expect(described_class).to have_received(:new).with(:new, :create)
      end

      it 'defines permit_edit_and_update_actions matcher' do
        expect(policy_factory).to permit_edit_and_update_actions

        expect(described_class).to have_received(:new).with(:edit, :update)
      end
    end

    describe 'negated matchers' do
      let(:test_matcher) { instance_double(described_class, does_not_match?: true) }

      before do
        allow(described_class).to receive(:new).and_return(test_matcher)
      end

      it 'defines forbid_new_and_create_actions matcher' do
        expect(policy).to forbid_new_and_create_actions

        expect(described_class).to have_received(:new).with(:new, :create)
      end

      it 'defines forbid_edit_and_update_actions matcher' do
        expect(policy_factory).to forbid_edit_and_update_actions

        expect(described_class).to have_received(:new).with(:edit, :update)
      end
    end
  end
end
