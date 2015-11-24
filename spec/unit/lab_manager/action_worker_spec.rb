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
      action_worker.perform(action.id)
      action.reload
      expect(action.state).to eq 'failed'
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

  context 'when take_snapshot action is requested' do
    let(:snapshot) { compute.snapshots.create!( name: 'foo') }
    let(:sample_provider_data) { { a: 'b', c: 'd', e: 'f', ref: '123' } }
    let(:action) { compute.actions.create!(command: :take_snapshot_vm, payload: {snapshot_id: snapshot.id}) }

    it 'fails when action payload is unset' do
      compute.enqueue!
      action = compute.actions.create!(command: :take_snapshot_vm)
      action_worker.perform(action.id)
      expect(action.reload.state).to eq 'failed'
      expect(action.reason).to eq 'Wrong action payload'
    end

    it 'fails when action payload doesn\'t have :snapshot_id' do
      compute.enqueue!
      action = compute.actions.create!(command: :take_snapshot_vm, payload: {})
      action_worker.perform(action.id)
      expect(action.reload.state).to eq 'failed'
      expect(action.reason).to eq 'Wrong action payload, no snapshot_id provided'
    end

    it 'fails when shapshot#provider_ref is already filled' do
      snapshot.provider_ref = '1225455'
      snapshot.save!
      compute.enqueue!
      action_worker.perform(action.id)
      expect(action.reload.state).to eq 'failed'
      expect(action.reason).to eq 'Snapshot already created'
    end

    it 'calls take_snapshot_vm on compute object' do
      expect_any_instance_of(::Compute).to receive(:take_snapshot_vm) { fail 'foo' }
      compute.enqueue!
      action_worker.perform(action.id)
      expect(action.reload.state).to eq 'failed'
      expect(action.reason).to eq 'foo'
    end

    it 'stores take_snapshot_vm\'s output to snapshot object' do
      allow_any_instance_of(::Compute).to receive(:take_snapshot_vm) { sample_provider_data }
      compute.enqueue!
      action_worker.perform(action.id)
      snapshot.reload
      expect(snapshot.provider_data.symbolize_keys).to eq sample_provider_data
    end

    it 'stores provider_ref to snapshot object' do
      allow_any_instance_of(::Compute).to receive(:take_snapshot_vm) { sample_provider_data }
      compute.enqueue!
      action_worker.perform(action.id)
      snapshot.reload
      expect(snapshot.provider_ref).to eq sample_provider_data[:ref]
    end
  end

  context 'when revert_snapshot action is requested' do
    let(:snapshot) { compute.snapshots.create!( name: 'foo') }
    let(:sample_provider_data) { { a: 'b', c: 'd', e: 'f', ref: '123' } }
    let(:action) { compute.actions.create!(command: :revert_snapshot_vm, payload: {snapshot_id: snapshot.id}) }

    it 'fails when action payload is unset' do
      allow_any_instance_of(::Compute).to receive(:vm_state) { :power_on }
      compute.enqueue!
      compute.provisioning!
      compute.run!
      action = compute.actions.create!(command: :revert_snapshot_vm)
      action_worker.perform(action.id)
      expect(action.reload.state).to eq 'failed'
      expect(action.reason).to eq 'Wrong action payload'
    end

    it 'fails when action payload doesn\'t have :snapshot_id' do
      allow_any_instance_of(::Compute).to receive(:vm_state) { :power_on }
      compute.enqueue!
      compute.provisioning!
      compute.run!
      action = compute.actions.create!(command: :revert_snapshot_vm, payload: {})
      action_worker.perform(action.id)
      expect(action.reload.state).to eq 'failed'
      expect(action.reason).to eq 'Wrong action payload, no snapshot_id provided'
    end

    it 'calls revert_snapshot_vm on compute object' do
      allow_any_instance_of(::Compute).to receive(:vm_state) { :power_on }
      expect_any_instance_of(::Compute).to receive(:revert_snapshot_vm) { fail 'foo' }
      compute.enqueue!
      compute.provisioning!
      compute.run!
      action_worker.perform(action.id)
      expect(action.reload.state).to eq 'failed'
      expect(action.reason).to eq 'foo'
    end

    context 'when revert_snapshot causes no exception and input is set properly' do
      it 'returns succeeded action' do
        allow_any_instance_of(::Compute).to receive(:vm_state) { :power_on }
        expect_any_instance_of(::Compute).to receive(:revert_snapshot_vm) { {} }
        compute.enqueue!
        compute.provisioning!
        compute.run!
        action_worker.perform(action.id)
        expect(action.reload.state).to eq 'success'
      end
    end

    context 'when take_snapshot was performed on running machine' do
      it 'outputs the compute in running state' do
        expect_any_instance_of(::Compute).to receive(:vm_state) { :power_on }
        expect_any_instance_of(::Compute).to receive(:revert_snapshot_vm) do
          {}
        end

        compute.enqueue!
        compute.provisioning!
        compute.run!
        action_worker.perform(action.id)
        expect(action.reload.state).to eq 'success'
        expect(compute.reload.state).to eq 'running'
      end
    end

    context 'when take_snapshot was performed on powered_off machine' do
      it 'outputs the compute in powered_off state' do
        expect_any_instance_of(::Compute).to receive(:vm_state) { :power_off }
        expect_any_instance_of(::Compute).to receive(:revert_snapshot_vm) do
          {}
        end

        compute.enqueue!
        compute.provisioning!
        compute.run!
        action_worker.perform(action.id)
        expect(action.reload.state).to eq 'success'
        expect(compute.reload.state).to eq 'powered_off'
      end
    end
  end
end
