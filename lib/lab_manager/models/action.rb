# == Schema Information
#
# Table name: actions
#
#  id          :integer          not null, primary key
#  compute_id  :integer
#  status      :string
#  reason      :text
#  payload     :text
#  pending_at  :datetime
#  finished_at :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

require 'aasm'

class Action < ActiveRecord::Base
  validates :status, inclusion: { in: %w(in_progress finished errored)}

  incluse AASM

  aasm no_direct_assignment: :true, column: :state do
    state :in_progress, initial: :true
    state :finished
    state :errored
  end
end
