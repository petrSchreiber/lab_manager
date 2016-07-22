# == Schema Information
#
# Table name: actions
#
#  id          :integer          not null, primary key
#  compute_id  :integer
#  command     :string           default(""), not null
#  state       :string           default("queued"), not null
#  reason      :text
#  payload     :text
#  job_id      :string
#  pending_at  :datetime
#  finished_at :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

require 'aasm'
require 'lab_manager/workers/action_worker'
require 'lab_manager/storage_uploader'
require 'carrierwave/orm/activerecord'

# Action model, it is used as the store of actions which were dispatched to a compute
class Action < ActiveRecord::Base
  DONE_STATES = %w(success failed)
  TODO_STATES = %(queued)
  FAIL_STATES = %(failed)

  belongs_to :compute, inverse_of: :actions

  # TODO: create_vm - is it usefull?
  validates :command,
            inclusion: { in: %w(create_vm suspend_vm shutdown_vm reboot_vm
                                revert_snapshot_vm resume_vm processes_vm
                                poweron_vm poweroff_vm take_snapshot_vm execute_vm
                                terminate_vm upload_file_vm download_file_vm) },
            presence: true

  validates :state,
            inclusion: { in: %w(queued pending success failed) },
            presence: true

  serialize :payload

  has_one :file_storage, inverse_of: :action

  validates :file_storage, presence: true, if: ->(a) { a.command == 'upload_file_vm' }

  after_commit :schedule_action, on: :create

  include AASM

  aasm no_direct_assignment: :true, column: :state do
    state :queued, initial: :true
    state :pending
    state :success
    state :failed

    event :pending   do transitions from: :queued, to: :pending end
    event :succeeded do transitions from: :pending, to: :success end
    event :failed    do transitions from: :pending, to: :failed   end
    event :reenqueue do transitions from: :pending, to: :queued end
  end

  scope :done, -> { where(state: DONE_STATES) }
  scope :todo, -> { where(state: TODO_STATES) }
  scope :failed, -> { where(state: FAIL_STATES) }

  def schedule_action
    LabManager.logger.debug "Scheduling action id=#{self.id}"
    LabManager::ActionWorker.perform_async(self.id)
  end

  def reschedule_action(interval_time = 2.minutes)
    self.reenqueue!
    LabManager.logger.debug "Rescheduling action id=#{self.id} in: #{interval_time}"
    LabManager::ActionWorker.perform_in(interval_time, self.id)
  end
end
