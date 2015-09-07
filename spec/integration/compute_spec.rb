require 'spec_helper'

require 'compute'

describe Compute do
  it "creates a VM" do
    machine = Compute.create!(
      provider: 'vspehre',
      image: '...',
    )
  end
end
