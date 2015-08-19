require 'settingslogic'

module LabManager
  class Config < Settingslogic
    source "#{LabManager.root}/config/labmanager.yml"
    namespace LabManager.env
  end
end
