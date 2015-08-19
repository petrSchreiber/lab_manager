module LabManager
  class Config < SettingsLoginc
    source "#{LabManager.root}/config/labmanager.yml"
    namespace LabManager.env
  end
end
