require 'factory_girl'
require 'securerandom'

FactoryGirl.define do
  factory :action do
    command 'create_vm'
  end

  factory :compute do
    image '7x64'
    transient { with_actions 0 }

    after(:create) do |compute, evaluator|
      if evaluator.with_actions > 0
        create_list(:action, evaluator.with_actions, compute: compute)
      end
    end

    trait :v_sphere do
      provider_name 'v_sphere'
    end

    trait :static do
      provider_name 'static_machine'
    end
  end
end
