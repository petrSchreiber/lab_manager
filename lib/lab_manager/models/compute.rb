# == Schema Information
#
# Table name: computes
#
#  id                :integer          not null, primary key
#  name              :string
#  state             :string
#  image             :string
#  provider_name     :string
#  user_data         :text
#  ips               :text
#  create_vm_options :text
#  provider_data     :text
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

require 'active_support/core_ext/module/delegation'
require 'aasm'

# model representing a virtual machine
class Compute < ActiveRecord::Base
  ALIVE_STATES = %w(created provisioning running rebooting shutting_down
                    powered_off powering_on suspending suspended resuming reverting)
  DEAD_STATES = %w(terminating terminated errored)
  ACTION_PENDING_STATES = ALIVE_STATES - %w(running stopped powered_off)

  has_many :actions, dependent: :destroy, inverse_of: :compute
  # has_one   :provider, as: :providerable
  # has_many :snapshots, dependent: destroy

  validates :image, :provider, presence: true
  validates :state, inclusion: { in: %w(
    created provisioning running rebooting
    shutting_down powered_off powering_on
    suspending suspended resuming reverting
    terminating terminated errored) }

  serialize :create_vm_options
  serialize :provider_data

  delegate :terminate,
           :power_off,
           :power_on,
           :reboot,
           :shutdown,
           :execute, to: :provider_inst

  include AASM

  aasm no_direct_assignment: :true, column: :state do
    state :created, initial: true
    state :queued
    state :provisioning
    state :running
    state :rebooting
    state :shutting_down
    state :powered_off
    state :powering_on
    state :suspending
    state :suspended
    state :resuming
    state :reverting

    state :terminating
    state :terminated
    state :errored

    event :enqueue       do transitions from: :created,        to: :queued        end
    event :received      do transitions from: :queued,         to: :received      end
    event :provisioning  do transitions from: :queued,         to: :provisioning  end
    event :run           do transitions from: :provisioning,   to: :running       end

    event :reboot        do transitions from: :running,        to: :rebooting     end
    event :rebooted      do transitions from: :rebooting,      to: :running       end

    event :shut_down     do transitions from: :running,        to: :shutting_down end
    event :powered_off   do transitions from: :shutting_down,  to: :powered_off   end
    event :power_on      do transitions from: :powered_off,    to: :powering_on   end
    event :powered_on    do transitions from: :shutting_down,  to: :powered_off   end

    event :suspend       do transitions from: :running,        to: :suspending    end
    event :suspended     do transitions from: :suspending,     to: :suspended     end
    event :resume        do transitions from: :suspended,      to: :resuming      end
    event :resumed       do transitions from: :resuming,       to: :running       end

    event :revert        do transitions from: :running,        to: :reverting     end
    event :reverted      do transitions from: :reverting,      to: :running       end

    event :take_snapshot do
      transitions from: :running, to: :running
      transitions from: :suspended,      to: :suspended
      transitions from: :powered_off,    to: :powered_off
    end

    event :exec_script   do transitions from: :running,        to: :running       end

    event :terminated    do transitions from: :terminating,    to: :terminated    end

    event :terminate     do
      transitions from: [:created, :queued,
                         :received, :running,
                         :suspended,
                         :powered_off], to: :terminating
    end

    event :fatal_error do
      transitions from: [:created, :queued,
                         :received, :running,
                         :suspended, :pending,
                         :powered_off], to: :errored
    end
  end

  scope :alive, -> { where(state: ALIVE_STATES) }
  scope :dead,  -> { where(state: DEAD_STATES) }

  # after_commit :create_initial_action, on: :create

  def provider
    @provider ||= "::Providers::#{provider_name.to_s.camelize}".constantize.new(self)
  end

  def dead_state?
    DEAD_STATES.include?(state)
  end

  ##

  # def enqueue(data = {})
  #  LabManager.logger.info("Enqueueing compute id:#{id}")
  #  provider.enqueue(data)
  # end

  ##

  # def execute(command:, password:, user:)
  # end

  # def ip
  #  ips.first
  # end
end
