require 'ostruct'
require 'spec_helper'
require 'rbvmomi'

describe Provider::VSphere do
  let(:connection_pool_mock) { double('connection_pool_mock') }
  let(:vsphere_mock) { double('vsphere_mock') }
  let(:vm_defaults) do
    {
      linked_clone: true,
      datacenter: 'doo',
      template_path: 'aoo/boo/coo',
      dest_folder: 'zoo/xoo/coo',
      cluster: 'kokoko',
      power_on: true
    }
  end

  let(:vm_clone_response) do
    {
      'power_state' => 'poweredOn',
      'vm_ref' => 'xxxx',
      'new_vm' => { 'id' => SecureRandom.uuid }
    }
  end

  let!(:provider) do
    Provider::VSphere.new(build(:compute, provider_name: :v_sphere, name: 'foo'))
  end

  before(:each) do
    allow(Provider::VSphereConfig).to receive(:create_vm_defaults) { {} }
    allow(Provider::VSphere).to receive(:connect) { connection_pool_mock }
    allow(connection_pool_mock).to receive(:with).and_yield(vsphere_mock)
    allow(Provider::VSphereConfig).to receive(:create_vm_defaults) { vm_defaults }
  end

  describe '#create_vm' do
    it 'arguments are propagated to fog#clone_vm' do
      args = {
        name: 'a',
        datacenter: 'b',
        template_path: 'c',
        cluster: 'd',
        linked_clone: false,
        power_on: true,
        dest_folder: 'z'
      }
      expect(vsphere_mock).to receive(:vm_clone) do |param|
        expect(param['name']).to eq args[:name]
        expect(param['datacenter']).to eq args[:datacenter]
        expect(param['template_path']).to eq args[:template_path]
        expect(param['cluster']).to eq args[:cluster]
        expect(param['linked_clone']).to eq args[:linked_clone]
        expect(param['power_on']).to eq args[:power_on]
        expect(param['dest_folder']).to eq args[:dest_folder]

        vm_clone_response
      end

      allow(provider).to receive(:power_on) {}
      provider.create_vm(args)
    end

    it 'default arguments are propagated to fog#clone_vm as well' do
      expect(vsphere_mock).to receive(:vm_clone) do |param|
        expect(param['datacenter']).to eq 'doo'
        expect(param['template_path']).to eq 'aoo/boo/coo'
        expect(param['cluster']).to eq 'kokoko'
        expect(param['linked_clone']).to eq true
        expect(param['power_on']).to eq true
        expect(param['dest_folder']).to eq 'zoo/xoo/coo'

        vm_clone_response
      end

      allow(provider).to receive(:power_on) {}
      provider.create_vm
    end

    it 'name is generated automatically when not provided' do
      expect(vsphere_mock).to receive(:vm_clone) do |param|
        expect(param['name']).to match(/^lm/)

        vm_clone_response
      end

      allow(provider).to receive(:power_on) {}
      provider.create_vm
    end

    it 'add_machine_to_drs_rule is called when requested' do
      allow(vsphere_mock).to receive(:vm_clone) { vm_clone_response }

      allow(provider).to receive(:power_on) {}
      expect(provider).to receive(:add_machine_to_drs_rule_impl) do |_obj, params|
        expect(params[:group]).to eq 'GroupFoo'
      end

      expect(provider).to receive(:machine_present_in_drs_rule?) do |_obj, params|
        expect(params[:group]).to eq 'GroupFoo'
      end

      provider.create_vm(add_to_drs_group: 'GroupFoo')
    end

    it 'power_on is called when machine is created in powered-off state' do
      allow(vsphere_mock).to receive(:vm_clone) do
        vm_clone_response.merge('power_state' => 'poweredOff')
      end

      expect(provider).to receive(:power_on).once
      provider.create_vm
    end

    it 'provider_data are set to underlying compute object' do
      allow(vsphere_mock).to receive(:vm_clone) { vm_clone_response }

      c = provider.compute
      expect(provider).to receive(:power_on).once
      provider.create_vm
      expect(c.provider_data['id']).to eq vm_clone_response['new_vm']['id']
    end

    it 'does not call terminate_vm when vm_clone fails' do
      allow(vsphere_mock).to receive(:vm_clone).and_raise(RbVmomi::Fault.new 'blah blah ', 'fooDDD')

      expect(provider).to receive(:terminate_vm).never
      expect { provider.create_vm }.to raise_error('fooDDD')
    end

    it 'calls terminate_vm when VM instance created but setup failed' do
      allow(vsphere_mock).to receive(:vm_clone) { vm_clone_response }

      allow(provider).to receive(:power_on).and_raise(RbVmomi::Fault.new 'blah blah blah', 'fooGGG')
      expect(provider).to receive(:terminate_vm).once
      expect { provider.create_vm }.to raise_error('fooGGG')
    end
  end

  describe '#power_on' do
    it 'fails when provider data are not present' do
      provider.compute.provider_data = nil
      expect { provider.power_on }.to raise_error(ArgumentError)
    end

    it 'uses correct id from provider_data field' do
      expect(vsphere_mock).to receive(:vm_power_on) do |param|
        expect(param['instance_uuid']).to eq('fooo')

        {
          'task_state' => 'success'
        }
      end

      expect(vsphere_mock).to receive(:get_virtual_machine).and_return({})
      provider.compute.provider_data = { 'id' => 'fooo' }
      provider.power_on
    end

    it 'retries fog#vm_power_on call when it fails and finally raises error' do
      expect(vsphere_mock).to receive(:vm_power_on).at_least(:twice).and_return(
        'task_state' => 'failed'
      )

      provider.compute.provider_data = { 'id' => 'fooo' }
      expect { provider.power_on }.to raise_error(Provider::VSphere::PowerOnError)
    end
  end

  describe '#terminate_vm' do
    it 'fails when provider data are not present' do
      provider.compute.provider_data = nil
      expect { provider.terminate_vm }.to raise_error(ArgumentError)
    end

    it 'uses correct id from provider_data field' do
      servers = double('servers')
      server = double('server to be terminated', destroy: { 'task_state' => 'success' })
      expect(servers).to receive(:get) do |param|
        expect(param).to eq 'fo'
        server
      end

      allow(vsphere_mock).to receive(:servers).and_return(servers)
      provider.compute.provider_data = { 'id' => 'fo' }
      provider.terminate_vm
    end

    it 'retries server#destroy call when it fails and finally raises error ' do
      servers = double('servers')
      server = double('server to be terminated', destroy: { 'task_state' => 'failed' })
      allow(servers).to receive(:get) { server }

      allow(vsphere_mock).to receive(:servers).and_return(servers)
      provider.compute.provider_data = { 'id' => 'fo' }
      expect(server).to receive(:destroy).at_least(:twice)
      expect { provider.terminate_vm }.to raise_error(Provider::VSphere::TerminateVmError)
    end
  end
end
