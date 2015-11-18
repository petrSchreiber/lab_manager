describe Snapshot do
  let(:compute) { create(:compute, provider_name: 'v_sphere', name: 'one') }
  let(:subject) { compute.snapshots.create!(name: 'snapshot name') }

  it 'serializes provider_data' do
    subject.provider_data = { xxx: 1, yyy: 2 }
    subject.save!
    subject.reload
    expect(subject.provider_data).to eq('xxx' => 1, 'yyy' => 2)
  end
end
