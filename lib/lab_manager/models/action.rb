# == Schema Information
#
# Table name: actions
#
#  id          :integer          not null, primary key
#  compute_id  :integer
#  status      :string           default("queued")
#  reason      :text
#  payload     :text
#  pending_at  :datetime
#  finished_at :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

require 'aasm'

class Action < ActiveRecord::Base

  belongs_to :compute, inverse_of: :actions

  validates :status, inclusion: { in: %w(queued pending success failed)}

  include AASM

  aasm no_direct_assignment: :true, column: :state do
    state :queued, initial: :true
    state :pending
    state :success
    state :failed
  end
end
