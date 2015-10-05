require 'spec_helper'
require 'sidekiq/testing'

describe Compute do
  describe 'states trasition' do
    it 'default state is created' do
      expect(build(:compute).state).to eq 'created'
    end

    it 'cannot change state from created to running' do
      expect do
        build(:compute).run
      end.to raise_exception(AASM::InvalidTransition)
    end

    it 'can go throught states created->queued->provisioning->running->terminating->terminated' do
      action = build(:compute)
      expect(action.enqueue).to be true
      expect(action.provisioning).to be true
      expect(action.run).to be true
      expect(action.terminate).to be true
      expect(action.terminated).to be true
    end

    it 'chage attribute state raises exception' do
      expect do
        build(:compute).state = :queued
      end.to raise_exception(AASM::NoDirectAssignmentError)
    end

    describe '#schedule_create_vm!' do
      let(:compute) { create(:compute, provider_name: 'v_sphere', image: 'TA_7x64') }

      it 'changes state to queued' do
        compute.schedule_create_vm!
        expect(compute.state).to eq('queued')
      end

      it 'saves (persist) compute DB' do
        compute.schedule_create_vm!
        expect(compute.changed?).to be false
      end

      it 'creates create_vm action and persis it to DB' do
        expect do
          compute.schedule_create_vm!
        end.to change { compute.actions.count }.by(1)
        expect(compute.actions.last.persisted?).to be true
      end
    end
  end
end
