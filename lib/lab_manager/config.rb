require 'settingslogic'

module LabManager
  # settings of labmanager application
  class Config < Settingslogic
    def initialize(source = nil, section = nil)
      source ||= File.join(LabManager.root, 'config', 'lab_manager.yml')

      self.class.namespace LabManager.env
      super(source, section)
    end
  end
end
