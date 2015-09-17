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
  end
end
