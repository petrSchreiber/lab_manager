# == Schema Information
#
# Table name: computes
#
#  id         :integer          not null, primary key
#  name       :string
#  state      :string
#  image      :string
#  provider   :string
#  user_data  :text
#  ips        :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Compute < ActiveRecord::Base
  validates :image, :provider, presence: true
  validates :state, inclusion: { in: %w(pending running rebooting stopping stopped shutting-downn terminated) }

end
