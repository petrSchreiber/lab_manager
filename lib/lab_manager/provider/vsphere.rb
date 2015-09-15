require 'fog'
require 'lab_manager/provider/vsphere_config'
require 'connection_pool'

module Provider
  # VSphere provider implementation
  class VSphere
    class << self
      def connect
        @vspehre ||= ConnectionPool.new(
          size: VSphereConfig.connection_pool.size,
          timeout: VSphereConfig.connection_pool.timeout
        ) do
          Fog::Compute.new(
            provider: :vsphere,
            vsphere_username: VSphereConfig.username,
            vsphere_password: VSphereConfig.password,
            vsphere_server: VSphereConfig.server,
            vsphere_expected_pubkey_hash: VSphereConfig.expected_pubkey_hash
          )
        end
      end

      def filter_machines_to_be_scheduled(
            queued_machines: Compute.queued.where(provider_name: 'v_sphere'),
            alive_machines: Compute.alive.where(provider_name: 'v_sphere').order(:created_at)
      )
        queued_machines.limit([0, VSphereConfig.scheduler.max_vm - alive_machines.count].max)
      end
    end

    attr_accessor :compute

    def initialize(compute)
      @compute = compute
    end

    def create_vm_options
      compute.create_vm_options
    end

    # TODO: what parameters are mandatory?
    # whould be nice to be able to validate before sendting a request

    def run
      opts = create_vm_options.reverse_merge(VSphereConfig.run_default_opts)
      VSphere.connect.with do |vs|
        vs.vm_clone(
          'datacenter'    => opts[:datacenter],
          'template_path' => template_uid,
          'name'          => opts[:name],

          'cluster'       => opts[:cluster],
          'linked_clone'  => opts[:linked_clone],
          'dest_folder'   => compute.dest_folder || default_dest_folder(opts)
        )
      end
    end

    private

    def default_dest_folder(opts)
      # "LabManager/default/#{opts[:lm_meta][:repo]}-#{opts[:lm_meta][:tsd]}"
      # e.g: 'LabManager/%{repoitory}s/%{tsd}s' % opts[:lm_meta]
      opts[:dest_folder_formatter] % opts.merge(opts[:lm_meta])
    end
  end
end
