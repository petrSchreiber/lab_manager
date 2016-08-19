# == Schema Information
#
# Table name: file_storages
#
#  id        :integer          not null, primary key
#  action_id :integer
#  file      :string
#

require 'lab_manager/models/action'
require 'carrierwave'

# Storage of files to be uploaded or downloaded
class FileStorage < ActiveRecord::Base
  belongs_to :action, inverse_of: :file_storage

  mount_uploader :file, StorageUploader
end
