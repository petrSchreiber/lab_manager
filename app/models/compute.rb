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

  ALIVE_STATES = %w(created queued pending running rebooting stopping stopped shutting-down poweron poweroff)
  DEAD_STATES = %w(terminated errored)

  #has_one   :provider, as: :providerable
  #has_many :snapshots, dependant: destroy

  validates :image, :provider, presence: true
  validates :state, inclusion: { in: %w(
   created queued pending running
   rebooting stopping stopped shutting-downn
   terminated errored) }


  #include ActiveModel::Transitions

  #state_machine do
  #  state :created    # first one is initial state; just created item in DB
  #  state :queued     # scheduled to background job
  #  state :received   # backgound job starts processing
  #  state :pending    # REDUNDANT? sets imedialtelly before fog strarts prepare machine
  #  state :running    # fog starts the VM

  #  state :rebooting
  #  state :stopping
  #  state :stopped
  #  state :shuttingdown

  #  state :powering_off # ??
  #  state :powering_on  # ??

  #  state :terminated
  #  state :errored

  #  event :enqueue { transition to: :queued, from: :created, on_transition: :enqueue }
  #  event :receive { transition to: :received, from: :queued }
  #  event :pending { transition to: :pending, from: [:received, :enqueued] }
  #  event :running { transition to: :running, from: [:pending] }

  #  event :reboot { transition to: :rebooting, from: :running }
  #  event :rebooted { transition to: :rebooting, from: :running }

  #  event :powering_off { transition to: :powering_off, from: [:pending, :running] }
  #  event :powered_off { transition to: :stopped, from: [:powering_off, :running] }


  #  event :powering_on { transition to: :powering_on, from: [:stopped] }
  #  event :powered_on { transition to: :running, from: [:powering_on, :stopped] }
  #end


  scope :alive, -> { where(state: ALIVE_STATES) }
  scope :dead,  -> { where(state: ALIVE_STATES) }


  ##

  def enqueue(data = {})
    LabManager.logger.info("Enqueuing compute id:#{id}")
    provider.enqueue(data)
  end

  ##

  def terminate
  end

  def shutdown
  end

  def power_on
  end

  def power_off
  end

  def reboot
  end

  def execute(command:, password:, user:)
  end


  def ip
    ips.first
  end
end
