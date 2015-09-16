require 'spec_helper'
require 'sidekiq/testing'

describe Action do
  describe 'states trasition' do
    it 'default statet is queued' do
      expect(build(:action).state).to eq 'queued'
    end

    it 'cannot change state from queued to success' do
      expect do
        build(:action).succeeded
      end.to raise_exception(AASM::InvalidTransition)
    end

    it 'can go throught states queued->pending->success' do
      action = build(:action)
      expect(action.pending).to be true
      expect(action.succeeded).to be true
    end

    it 'chage attribute state raises exception' do
      expect do
        build(:action).state = :pending
      end.to raise_exception(AASM::NoDirectAssignmentError)
    end
  end

  it 'automatically schedule events when action is created', sidekiq: true do
    expect do
      create(:action)
    end.to change(LabManager::ActionWorker.jobs, :size).by(1)
  end
end
