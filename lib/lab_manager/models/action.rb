# == Schema Information
#
# Table name: actions
#
#  id          :integer          not null, primary key
#  compute_id  :integer
#  command     :string           default(""), not null
#  state       :string           default("queued")
#  reason      :text
#  payload     :text
#  job_id      :string
#  pending_at  :datetime
#  finished_at :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

require 'aasm'

class Action < ActiveRecord::Base
  DONE_STATES = %w(success failed)
  TODO_STATES = %(queued)
  FAIL_STATES = %(failed)

  belongs_to :compute, inverse_of: :actions

  # TODO: create_vm - is it usefull?
  validates :command,
            inclusion: { in: %w(create_vm suspend shut_down reboot revert resume power_on
                                take_snapshot execute_script terminate) },
            presence: true

  validates :state,
            inclusion: { in: %w(queued pending success failed) },
            presence: true

  serialize :payload

  include AASM

  aasm no_direct_assignment: :true, column: :state do
    state :queued, initial: :true
    state :pending
    state :success
    state :failed

    event :pending   do transitions from: :queued, to: :pending end
    event :succedded do transitions from: :pending, to: :succeded end
    event :failed    do transitions from: :pending, to: :failed   end
  end

  scope :done, -> { where(state: DONE_STATES) }
  scope :todo, -> { where(state: TODO_STATES) }
  scope :failed, -> { where(state: FAIL_STATES) }
end
