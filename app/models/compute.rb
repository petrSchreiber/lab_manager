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
  has_one   :provider, polymorphic: true
  #has_many :snapshots, dependant: destroy

  validates :image, :provider, presence: true
  validates :state, inclusion: { in: %w(pending running rebooting stopping stopped shutting-downn terminated) }

  #asi ne: delegate :run, :terinate, :shutdown, :poweron, :poweroff, to: :provider

  #state :created
  #state :queued       #put to the sidekiq queue (scheduler decided to run)
  #state :pending_run  #sidekiq job start to process it, ...or Provider start to process it.
  #state :run
  #
  #state :pending_terminate
  #state :terminate
  #
  #state :pending_shutdown
  #state :shutdown
  #
  #state :pending_poweron
  #state :poweron
  #
  #state :pending_poweroff
  #state :poweroff

  def as_json
    #TODO ...merge with specific provider items?
  end

  def run(opts)

  end

  def terminate
  end

  def shutdown
  end

  def poweron
  end

  def poweroff
  end
end
