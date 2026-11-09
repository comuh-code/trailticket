# frozen_string_literal: true

FactoryBot.define do
  factory :ticket, class: 'Trailticket::Ticket' do
    title { 'Login broken' }
    body { "Can't sign in" }
    author factory: %i[admin member]
  end
end
