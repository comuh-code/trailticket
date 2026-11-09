# frozen_string_literal: true

FactoryBot.define do
  factory :admin do
    role { 'member' }
    name { role.capitalize }

    %w[member agent guest].each do |r|
      trait(r.to_sym) { role { r } }
    end
  end
end
