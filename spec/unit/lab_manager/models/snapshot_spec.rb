describe Snapshot do
  let(:compute) { create(:compute, provider_name: 'v_sphere', name: 'one') }
  let(:subject) { compute.snapshots.create!(name: 'name') }

  it 'serializes provider_data' do
    subject.provider_data = { xxx: 1, yyy: 2 }
    subject.save!
    subject.reload
    expect(subject.provider_data).to eq('xxx' => 1, 'yyy' => 2)
  end

  describe 'ensure uniqeness on pair {name, compute_id}' do
    it 'saves same name on different compute_id' do
      compute.snapshots.create!(name: 's1')
      compute2 = create(:compute, provider_name: 'v_sphere', name: 'one')
      snapshot2 = compute2.snapshots.new(name: 's1')
      expect(snapshot2.valid?).to be true
    end

    it 'validates same name cannot be used multiple times' do
      compute.snapshots.create!(name: 's1')
      snapshot2 = compute.snapshots.new(name: 's1')
      expect(snapshot2.valid?).to be false
    end
  end
end
