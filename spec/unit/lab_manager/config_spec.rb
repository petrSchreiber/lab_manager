require 'spec_helper'

describe LabManager::Config do
  it "raise exception for non-exist key" do
    expect {
      LabManager::Config.new.abcdef
    }.to raise_error(Settingslogic::MissingSetting)
  end

  it "fetch existing key" do
    expect(LabManager::Config.new.log_level).to be_kind_of(Integer)
  end
end
