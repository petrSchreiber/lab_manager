require 'active_record'

module LabManager
  module Database
    class << self

      def config
        YAML.load(File.read(File.join(LabManager.root, 'config', 'database.yml')))
      end

      def connect
        ActiveRecord::Base.logger = LabManager.logger

        ActiveRecord::Base.configurations = Database.config
        ActiveRecord::Base.establish_connection(LabManager.env.to_sym)
      end
    end
  end
end

