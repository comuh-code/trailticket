# frozen_string_literal: true

RSpec.describe Trailticket::Ticket do
  let(:member) { create(:admin, :member) }

  describe 'defaults' do
    subject(:ticket) { create(:ticket, author: member) }

    it { is_expected.to be_status_open }
    it { is_expected.to be_priority_normal }
    it { expect(ticket.context).to eq({}) }
  end

  describe 'validations' do
    subject(:ticket) { described_class.new(author: member, status: 'nope') }

    it 'requires title and body and a known status' do
      expect(ticket).not_to be_valid
      expect(ticket.errors).to include(:title, :body, :status)
    end
  end

  describe '#close! and #reopen!' do
    let(:agent) { create(:admin, :agent) }
    let(:ticket) { create(:ticket, author: member) }

    it 'keeps closed_at and closed_by in sync' do
      ticket.close!(by: agent)
      expect(ticket).to be_status_closed
      expect(ticket.closed_at).not_to be_nil
      expect(ticket.closed_by).to eq(agent)

      ticket.reopen!
      expect(ticket).to be_status_open
      expect(ticket.closed_at).to be_nil
      expect(ticket.closed_by).to be_nil
    end
  end

  describe 'on_status_changed hook' do
    let(:calls) { [] }

    before { Trailticket.config.on_status_changed = ->(_t, from, to) { calls << [from, to] } }
    after { Trailticket.config.on_status_changed = nil }

    it 'is called with the old and new status' do
      create(:ticket, author: member).update!(status: 'in_progress')
      expect(calls).to eq([%w[open in_progress]])
    end
  end

  describe 'Trailticket.open_ticket' do
    it 'stores sanitized context, page_url and screenshot' do
      ticket = Trailticket.open_ticket(
        author: member, title: 'Bug', body: 'Broken',
        context: { page: { url: 'https://app.test/x?token=abc&step=2' } },
        screenshot: png_data_url, user_agent: 'Test/1.0'
      )

      expect(ticket).to be_persisted
      expect(ticket.page_url).to eq('https://app.test/x?token=%5BFILTERED%5D&step=2')
      expect(ticket.context.dig('page', 'user_agent')).to eq('Test/1.0')
      expect(ticket).to be_screenshot
    end

    it 'rejects a bad screenshot without saving' do
      ticket = Trailticket.open_ticket(author: member, title: 'Bug', body: 'Broken',
                                       screenshot: data_url('image/png', 'not a png'))

      expect(ticket).not_to be_persisted
      expect(ticket.errors).to include(:screenshot)
    end

    it 'stores metadata in the context with string keys, without sanitizing it' do
      ticket = Trailticket.open_ticket(
        author: member, title: 'Bug', body: 'Broken',
        context: { page: { url: 'https://app.test/x' } },
        metadata: { comuhub: { admin: 1, comunidade: 'Centro', token: 'kept' } }
      )

      expect(ticket).to be_persisted
      expect(ticket.reload.context).to include(
        'page' => { 'url' => 'https://app.test/x' },
        'comuhub' => { 'admin' => 1, 'comunidade' => 'Centro', 'token' => 'kept' }
      )
    end

    it 'raises when metadata uses a reserved context key' do
      %i[page trail fields errors].each do |key|
        expect do
          Trailticket.open_ticket(author: member, title: 'Bug', body: 'Broken',
                                  metadata: { key => {} })
        end.to raise_error(ArgumentError, /#{key}/)
      end
      expect(described_class.count).to eq(0)
    end

    it 'uses the given page_url, cleaned, instead of the context one' do
      ticket = Trailticket.open_ticket(
        author: member, title: 'Bug', body: 'Broken',
        context: { page: { url: 'https://app.test/from-context' } },
        page_url: 'https://app.test/given?password=abc&step=2'
      )

      expect(ticket.page_url).to eq('https://app.test/given?password=%5BFILTERED%5D&step=2')
      expect(ticket.context.dig('page', 'url')).to eq('https://app.test/from-context')
    end

    it 'keeps the previous behavior without page_url and metadata' do
      ticket = Trailticket.open_ticket(
        author: member, title: 'Bug', body: 'Broken',
        context: { page: { url: 'https://app.test/x' }, extra: 'dropped' }
      )

      expect(ticket.page_url).to eq('https://app.test/x')
      expect(ticket.context).to eq('page' => { 'url' => 'https://app.test/x' })
    end
  end
end
