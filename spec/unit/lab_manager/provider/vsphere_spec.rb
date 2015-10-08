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
    Provider::VSphere.new(
      build(:compute, provider_name: :v_sphere, name: 'foo', image: 'AxAA')
    )
  end

  before(:each) do
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
        expect(param['template_path']).to eq 'AxAA'
        expect(param['cluster']).to eq args[:cluster]
        expect(param['linked_clone']).to eq args[:linked_clone]
        expect(param['power_on']).to eq args[:power_on]
        expect(param['dest_folder']).to eq args[:dest_folder]

        vm_clone_response
      end

      allow(provider).to receive(:poweron_vm) {}
      provider.create_vm(args)
    end

    it 'template_path argument is propagated to fog#clone_vm when compute.image is nil' do
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
        expect(param['template_path']).to eq 'c'
        expect(param['cluster']).to eq args[:cluster]
        expect(param['linked_clone']).to eq args[:linked_clone]
        expect(param['power_on']).to eq args[:power_on]
        expect(param['dest_folder']).to eq args[:dest_folder]

        vm_clone_response
      end

      allow(provider).to receive(:poweron_vm) {}
      provider.compute.image = nil
      provider.create_vm(args)
    end

    it 'default arguments are propagated to fog#clone_vm as well' do
      expect(vsphere_mock).to receive(:vm_clone) do |param|
        expect(param['datacenter']).to eq 'doo'
        expect(param['template_path']).to eq 'AxAA'
        expect(param['cluster']).to eq 'kokoko'
        expect(param['linked_clone']).to eq true
        expect(param['power_on']).to eq true
        expect(param['dest_folder']).to eq 'zoo/xoo/coo'

        vm_clone_response
      end

      allow(provider).to receive(:poweron_vm) {}
      provider.create_vm
    end

    it 'name is generated automatically when not provided' do
      expect(vsphere_mock).to receive(:vm_clone) do |param|
        expect(param['name']).to match(/^lm/)

        vm_clone_response
      end

      allow(provider).to receive(:poweron_vm) {}
      provider.create_vm
    end

    it 'add_machine_to_drs_rule is called when requested' do
      allow(vsphere_mock).to receive(:vm_clone) { vm_clone_response }

      allow(provider).to receive(:poweron_vm) {}
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

      expect(provider).to receive(:poweron_vm).once
      provider.create_vm
    end

    it 'provider_data are set to underlying compute object' do
      allow(vsphere_mock).to receive(:vm_clone) { vm_clone_response }

      c = provider.compute
      expect(provider).to receive(:poweron_vm).once
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

      allow(provider).to receive(:poweron_vm).and_raise(RbVmomi::Fault.new 'blah blah', 'fooGGG')
      expect(provider).to receive(:terminate_vm).once
      expect { provider.create_vm }.to raise_error('fooGGG')
    end
  end

  describe '#poweron_vm' do
    it 'fails when provider data are not present' do
      provider.compute.provider_data = nil
      expect { provider.poweron_vm }.to raise_error(ArgumentError)
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
      provider.poweron_vm
    end

    it 'retries fog#vm_power_on call when it fails and finally raises error' do
      expect(vsphere_mock).to receive(:vm_power_on).at_least(:twice).and_return(
        'task_state' => 'failed'
      )

      provider.compute.provider_data = { 'id' => 'fooo' }
      expect { provider.poweron_vm }.to raise_error(Provider::VSphere::PowerOnError)
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

      expect(vsphere_mock).to receive(:servers).and_return(servers)
      provider.compute.provider_data = { 'id' => 'fo' }
      provider.terminate_vm
    end

    it 'retries server#destroy call when it fails and finally raises error ' do
      servers = double('servers')
      server = double('server to be terminated', destroy: { 'task_state' => 'failed' })
      allow(servers).to receive(:get) { server }

      expect(vsphere_mock).to receive(:servers).at_least(:once).and_return(servers)
      provider.compute.provider_data = { 'id' => 'fo' }
      expect(server).to receive(:destroy).at_least(:twice)
      expect { provider.terminate_vm }.to raise_error(Provider::VSphere::TerminateVmError)
    end
  end

  describe '#shutdown_vm' do
    let(:servers) { double('servers') }
    let(:server) { double('server to be terminated') }

    it 'fails when provider data are not present' do
      provider.compute.provider_data = nil
      expect { provider.shutdown_vm }.to raise_error(ArgumentError)
    end

    it 'fails when the machine does not exist' do
      expect(servers).to receive(:get).at_least(:once) { nil }

      provider.compute.provider_data = { 'id' => 'fo' }
      expect(vsphere_mock).to receive(:servers).at_least(:once).and_return(servers)
      expect { provider.shutdown_vm }.to raise_error(Provider::VSphere::VmNotExistsError)
    end

    it 'does nothing when the machine is already powered off' do
      expect(server).to receive(:power_state).at_least(:once) { 'poweredOff' }
      expect(servers).to receive(:get).at_least(:once) { server }
      expect(provider).to receive(:set_provider_data).once
      expect(vsphere_mock).to receive(:servers).at_least(:once).and_return(servers)
      expect(server).to receive(:stop).at_most(0).times
      provider.compute.provider_data = { 'id' => 'fo' }
      provider.shutdown_vm
    end

    context 'managed mode' do
      it 'calls server.stop with force when soft stop failed' do
        second_time = false
        expect(server).to receive(:power_state).at_least(:twice) do
          second_time ? 'poweredOff' : 'poweredOn'
        end
        expect(server).to receive(:stop).twice do |param|
          expect(param[:force]).to eq second_time
          second_time = true
          fail 'soft stop failed' if second_time
        end
        expect(servers).to receive(:get).at_least(:once) { server }

        expect(vsphere_mock).to receive(:servers).at_least(:once).and_return(servers)
        expect(vsphere_mock).to receive(:get_virtual_machine).at_least(:once) do
          { 'power_state' => 'poweredOff' }
        end
        provider.compute.provider_data = { 'id' => 'fo' }
        provider.shutdown_vm
      end
    end

    context 'hard mode' do
      it 'calls server.stop with force' do
        expect(server).to receive(:power_state).at_least(:twice) { 'poweredOn' }
        expect(server).to receive(:stop).at_least(:once) do |param|
          expect(param[:force]).to eq true
          fail 'Expected function called'
        end

        expect(servers).to receive(:get).at_least(:once) { server }
        expect(vsphere_mock).to receive(:servers).at_least(:once).and_return(servers)
        provider.compute.provider_data = { 'id' => 'fo' }
        expect { provider.shutdown_vm(mode: 'hard') }.to raise_error('Expected function called')
      end
    end

    context 'soft mode' do
      it 'calls server.stop without force' do
        expect(server).to receive(:power_state).at_least(:twice) { 'poweredOn' }
        expect(server).to receive(:stop).at_least(:once) do |param|
          expect(param[:force]).to eq false
          fail 'Expected function called'
        end

        expect(servers).to receive(:get).at_least(:once) { server }
        expect(vsphere_mock).to receive(:servers).at_least(:once).and_return(servers)
        provider.compute.provider_data = { 'id' => 'fo' }
        expect { provider.shutdown_vm(mode: 'soft') }.to raise_error('Expected function called')
      end
    end

    context 'unknown mode' do
      it 'throws an exception' do
        expect(server).to receive(:power_state).at_least(:twice) { 'poweredOn' }
        expect(server).to receive(:stop).at_most(0).times do
          fail 'Expected function called'
        end

        expect(servers).to receive(:get).at_least(:once) { server }
        expect(vsphere_mock).to receive(:servers).at_least(:once).and_return(servers)
        provider.compute.provider_data = { 'id' => 'fo' }
        expect do
          provider.shutdown_vm(mode: 'something unexpected')
        end.to raise_error(Provider::VSphere::ShutdownVmError)
      end
    end

    it 'refreshes provider data' do
      expect(server).to receive(:power_state).at_least(:once) { 'poweredOff' }
      expect(servers).to receive(:get).at_least(:once) { server }
      expect(provider).to receive(:set_provider_data).once
      expect(vsphere_mock).to receive(:servers).at_least(:once).and_return(servers)
      provider.compute.provider_data = { 'id' => 'fo' }
      provider.shutdown_vm
    end
  end

  describe '#reboot_vm' do
    let(:servers) { double('servers') }
    let(:server) { double('server to be rebooted') }

    it 'fails when provider data are not present' do
      provider.compute.provider_data = nil
      expect { provider.reboot_vm }.to raise_error(ArgumentError)
    end

    it 'fails when the machine does not exist' do
      expect(servers).to receive(:get).at_least(:once) { nil }

      provider.compute.provider_data = { 'id' => 'fo' }
      expect(vsphere_mock).to receive(:servers).at_least(:once).and_return(servers)
      expect { provider.shutdown_vm }.to raise_error(Provider::VSphere::VmNotExistsError)
    end

    context 'managed mode' do
      it 'calls server.reboot with force when soft reboot failed' do
        second_time = false
        expect(server).to receive(:reboot).at_least(:twice) do |param|
          expect(param[:force]).to eq second_time
          second_time = !second_time
          fail 'soft reboot failed' if second_time
        end

        expect(servers).to receive(:get).at_least(:once) { server }

        expect(vsphere_mock).to receive(:servers).at_least(:once).and_return(servers)
        provider.compute.provider_data = { 'id' => 'fo' }
        provider.reboot_vm
      end
    end

    context 'hard mode' do
      it 'calls server.reboot with force' do
        expect(server).to receive(:reboot).at_least(:once) do |param|
          expect(param[:force]).to eq true
          fail 'Expected function called'
        end

        expect(servers).to receive(:get).at_least(:once) { server }
        expect(vsphere_mock).to receive(:servers).at_least(:once).and_return(servers)
        provider.compute.provider_data = { 'id' => 'fo' }
        expect { provider.reboot_vm(mode: 'hard') }.to raise_error('Expected function called')
      end
    end

    context 'soft mode' do
      it 'calls server.reboot without force' do
        expect(server).to receive(:reboot).at_least(:once) do |param|
          expect(param[:force]).to eq false
          fail 'Expected function called'
        end

        expect(servers).to receive(:get).at_least(:once) { server }
        expect(vsphere_mock).to receive(:servers).at_least(:once).and_return(servers)
        provider.compute.provider_data = { 'id' => 'fo' }
        expect { provider.reboot_vm(mode: 'soft') }.to raise_error('Expected function called')
      end
    end

    context 'unknown mode' do
      it 'throws an exception' do
        expect(server).to receive(:reboot).at_most(0).times do
          fail 'Expected function called'
        end

        expect(servers).to receive(:get).at_least(:once) { server }
        expect(vsphere_mock).to receive(:servers).at_least(:once).and_return(servers)
        provider.compute.provider_data = { 'id' => 'fo' }
        expect do
          provider.reboot_vm(mode: 'something unexpected')
        end.to raise_error(Provider::VSphere::RebootVmError)
      end
    end
  end
end
