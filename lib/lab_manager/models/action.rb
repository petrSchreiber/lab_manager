# == Schema Information
#
# Table name: actions
#
#  id          :integer          not null, primary key
#  compute_id  :integer
#  command     :string           default(""), not null
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

  #TODO: create_vm - is it usefull?
  validates :command,
    inclusion: { in: %w(create_vm suspend shut_down reboot revert resume power_on
                        take_snapshot execute_script)},
    presence: true

  validates :status,
    inclusion: { in: %w(queued pending success failed)},
    presence: true

  serialize :payload

  include AASM

  aasm no_direct_assignment: :true, column: :state do
    state :queued, initial: :true
    state :pending
    state :success
    state :failed
  end
end
