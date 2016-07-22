require 'settingslogic'

module Provider
  # Configuration of the vsphere provider
  class VSphereConfig < Settingslogic
    source "#{LabManager.root}/config/provider_vsphere.yml"
    namespace LabManager.env
  end
end
