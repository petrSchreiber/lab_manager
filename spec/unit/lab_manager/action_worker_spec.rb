require 'spec_helper'
require 'sidekiq/testing'

describe LabManager::ActionWorker do
  let(:action_worker) { described_class.new }
  let(:compute)       { create(:compute, :v_sphere) }

  it 'locks the action before processing', sidekiq: true do
    action = compute.actions.create!(command: :create_vm)
    locked_by_thread = false
    thr = Thread.new do
      action.with_lock do
        locked_by_thread = true
        Thread.pass
        sleep 2
      end
    end
    Thread.pass until locked_by_thread

    expect do
      action_worker.perform(action.id)
    end.to raise_error(ActiveRecord::StatementInvalid)
    Thread.kill thr
  end

  context 'when a compute is in dead state' do
    it 'refuses to process given action when state=errored' do
      compute.fatal_error!
      action = compute.actions.create!(command: :create_vm)
      action_worker.perform(action.id)
      action.reload
      expect(action.state).to eq 'failed'
    end

    it 'refuses to process given action when state=terminating' do
      compute.fatal_error!
      action = compute.actions.create!(command: :create_vm)
      action_worker.perform(action.id)
      action.reload
      expect(action.state).to eq 'failed'
    end
  end

  context 'when passed action is not in pending state' do
    it 'refuses to process that action' do
      action = compute.actions.create!(command: :create_vm)
      action.pending!
      action_worker.perform(action.id)
      expect(action.reload.state).to eq 'failed'
    end
  end

  context 'when create_vm action is requested' do
    it 'calls create_vm method of compute object' do
      action = compute.actions.create!(command: :create_vm)
      expect_any_instance_of(::Compute).to receive(:create_vm)
      compute.enqueue
      compute.save!
      action_worker.perform(action.id)
    end

    it 'ends up in running state if provider throws no exception' do
      compute.enqueue!
      action = compute.actions.create!(command: :create_vm)
      allow_any_instance_of(::Compute).to receive(:create_vm) { true }
      action_worker.perform(action.id)
      compute.reload
      expect(compute.state).to eq('running')
      action.reload
      expect(action.state).to eq('success')
    end

    it 'ends up in errored state if provider throws an exception' do
      compute.enqueue!
      action = compute.actions.create!(command: :create_vm)
      allow_any_instance_of(::Compute).to receive(:create_vm) { fail 'foo' }
      expect do
        action_worker.perform(action.id)
      end.to raise_error(RuntimeError)
    end
  end

  context 'when terminate_vm action is requested' do
    it 'calls terminate_vm method of compute object' do
      compute.enqueue!
      action = compute.actions.create!(command: :create_vm)
      allow_any_instance_of(::Compute).to receive(:create_vm)
      action_worker.perform(action.id)
      action = compute.actions.create!(command: :terminate_vm)
      expect_any_instance_of(::Compute).to receive(:terminate_vm)
      action_worker.perform(action.id)
    end
  end

end
