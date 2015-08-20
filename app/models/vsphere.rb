require 'fog'
require 'vsphere_config'
require 'connection_pool'

class VSphere
  class << self
    def connect
      @vspehre ||= ConnectionPool.new(size: VSphereConfig.pool, timeout: VSphereConfig.timeout) do
        Fog::Compute.new(
          provider: :vsphere,
          vsphere_username: VSphereConfig.username,
          vsphere_password: VSphereConfig.password,
          vsphere_server: VSphereConfig.server,
          vsphere_expected_pubkey_hash: VSphereConfig.expected_pubkey_hash
        )
      end
    end
  end


  # TODO what parameters are mandatory?
  # whould be nice to be able to validate before sendting a request

  def run(template_uid, name, opts)
    opts = opts.reverse_merge(VSphereConfig.run_default_opts)
    VSphere.connect.with do |vs|
      vs.vm_clone(
        'datacenter'    => opts[:datacenter],
        'template_path' => template_uid,
        'name'          => opts[:name],

        'cluster'       => opts[:cluster],
        'linked_clone'  => opts[:linked_clone],
        'dest_folder'   => opts[:dest_folder] || default_dest_folder(opts)
      )
    end
  end

  def default_dest_folder
    # "LabManager/default/#{opts[:lm_meta][:repo]}-#{opts[:lm_meta][:tsd]}"
    # e.g: 'LabManager/%{repoitory}s/%{tsd}s' % opts[:lm_meta]
    opts[:dest_folder_formatter] % opts.merge(opts[:lm_meta])
  end
end
