require 'settingslogic'

class VSphereConfig < Settingslogic
  source "#{LabManager.root}/config/vsphere.yml"
  namespace LabManager.env
end
