require 'spec_helper'

describe LabManager::Config do
  it 'raises exception for non-exist key' do
    expect do
      LabManager::Config.new.abcdef
    end.to raise_error(Settingslogic::MissingSetting)
  end

  it 'fetches existing key' do
    expect(LabManager::Config.new.log_level).to be_kind_of(Integer)
  end
end
