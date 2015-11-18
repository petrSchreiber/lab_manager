# == Schema Information
#
# Table name: snapshots
#
#  id            :integer          not null, primary key
#  name          :string
#  compute_id    :integer
#  provider_ref  :string
#  provider_data :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

class Snapshot < ActiveRecord::Base
  belongs_to :compute, inverse_of: :snapshots

  serialize :provider_data, JSON

  validates :name, :compute, presence: true, allow_nil: false
end
