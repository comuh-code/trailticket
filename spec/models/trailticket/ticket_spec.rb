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

  describe 'config.statuses' do
    it 'needs an initial and a final status' do
      config = Trailticket::Configuration.new

      expect { config.statuses = %w[only] }.to raise_error(ArgumentError, /at least two/)
      config.statuses = %i[new done]
      expect(config.statuses).to eq(%w[new done])
    end
  end

  describe 'initial and final statuses' do
    let(:agent) { create(:admin, :agent) }

    before do
      allow(Trailticket.config).to receive_messages(
        statuses: %w[triage open resolved cancelled],
        initial_status: 'open',
        final_statuses: %w[resolved cancelled]
      )
    end

    it 'starts new tickets in initial_status' do
      expect(create(:ticket, author: member).status).to eq('open')
    end

    it 'treats every final status as closed and keeps closed_at between finals' do
      ticket = create(:ticket, author: member)
      ticket.close!(by: agent)
      expect(ticket.status).to eq('resolved')
      closed_at = ticket.closed_at

      ticket.update!(status: 'cancelled')
      expect(ticket.reload).to have_attributes(closed_at: closed_at, closed_by: agent)
      expect(described_class.active).to be_empty

      ticket.reopen!
      expect(ticket).to have_attributes(status: 'open', closed_at: nil, closed_by: nil)
    end
  end

  describe 'triage' do
    let(:agent) { create(:admin, :agent) }

    before { allow(Trailticket.config).to receive(:triage).and_return(true) }

    it 'opens tickets without a priority, keeping what the user picked as a suggestion' do
      ticket = Trailticket.open_ticket(author: member, title: 'Bug', body: 'x', priority: 'high')

      expect(ticket).to have_attributes(priority: nil, suggested_priority: 'high', status: 'open')
      expect(ticket).to be_needs_triage
    end

    it 'drops an unknown suggestion instead of refusing the ticket' do
      ticket = Trailticket.open_ticket(author: member, title: 'Bug', body: 'x', priority: 'asap')

      expect(ticket).to be_persisted
      expect(ticket.suggested_priority).to be_nil
    end

    it 'only leaves the initial status for a non-final one after it has a priority' do
      ticket = create(:ticket, author: member)

      expect(ticket.update(status: 'in_progress')).to be(false)
      expect(ticket.errors.of_kind?(:priority, :required_for_triage)).to be(true)

      ticket.reload.update!(priority: 'high')
      ticket.update!(status: 'in_progress')
      expect(ticket.reload.status).to eq('in_progress')
    end

    it 'lets an unprioritized ticket go straight to a final status' do
      ticket = create(:ticket, author: member)

      ticket.close!(by: agent)

      expect(ticket.reload.status).to eq('closed')
    end
  end

  describe 'without triage' do
    it 'keeps normal as the default priority and the one the user picked' do
      expect(create(:ticket, author: member).priority).to eq('normal')

      ticket = Trailticket.open_ticket(author: member, title: 'Bug', body: 'x', priority: 'high')
      expect(ticket).to have_attributes(priority: 'high', suggested_priority: nil)
    end
  end

  describe 'config validation' do
    it 'rejects unknown or conflicting initial/final statuses' do
      config = Trailticket::Configuration.new
      expect(config.validate!).to be(config)
      expect([config.initial_status, config.final_statuses]).to eq(['open', ['closed']])

      config.final_statuses = %w[closed done]
      expect { config.validate! }.to raise_error(ArgumentError, /unknown status done/)

      config.final_statuses = %w[open]
      expect { config.validate! }.to raise_error(ArgumentError, /initial_status cannot be final/)
    end
  end

  describe 'archiving' do
    let(:agent) { create(:admin, :agent) }
    let(:ticket) { create(:ticket, author: member) }

    it 'only archives tickets in a final status' do
      expect { ticket.archive! }.to raise_error(ActiveRecord::RecordInvalid, /final status/)

      ticket.close!(by: agent)
      ticket.archive!
      expect(ticket).to be_archived
      expect(described_class.archived).to eq([ticket])
      expect(described_class.unarchived).to be_empty
    end

    it 'records archive and unarchive in the history, and reopening unarchives' do
      Trailticket.with_actor(agent) do
        ticket.close!(by: agent)
        ticket.archive!
        ticket.unarchive!
        ticket.archive!
        ticket.reopen!
      end

      expect(ticket.reload.archived_at).to be_nil
      expect(ticket.events.map(&:action)).to eq(
        %w[status_changed archived unarchived archived status_changed]
      )
    end
  end

  describe 'on_status_changed actor' do
    let(:agent) { create(:admin, :agent) }
    let(:ticket) { create(:ticket, author: member) }

    it 'passes who made the change as a 4th argument' do
      calls = []
      allow(Trailticket.config).to receive(:on_status_changed)
        .and_return(->(_t, from, to, actor) { calls << [from, to, actor] })

      Trailticket.with_actor(agent) { ticket.update!(status: 'waiting') }

      expect(calls).to eq([['open', 'waiting', agent]])
    end

    it 'still accepts hooks with three arguments' do
      calls = []
      allow(Trailticket.config).to receive(:on_status_changed)
        .and_return(->(_t, from, to) { calls << [from, to] })

      ticket.update!(status: 'waiting')

      expect(calls).to eq([%w[open waiting]])
    end
  end

  describe 'history' do
    let(:agent) { create(:admin, :agent, name: 'Sergio') }
    let(:ticket) { create(:ticket, author: member) }

    it 'records status, priority and assignee changes with the current actor' do
      Trailticket.with_actor(agent) do
        ticket.update!(status: 'in_progress', priority: 'high')
        ticket.update!(assignee: agent)
        ticket.close!(by: agent)
      end

      expected = [
        ['status_changed', 'open', 'in_progress', agent],
        ['priority_changed', 'normal', 'high', agent],
        ['assignee_changed', nil, { 'type' => 'Admin', 'id' => agent.id }, agent],
        ['status_changed', 'in_progress', 'closed', agent]
      ]
      expect(ticket.events.map { |e| [e.action, e.from, e.to, e.actor] }).to eq(expected)
    end

    it 'records changes without a known actor as nil' do
      ticket.update!(status: 'waiting')

      expect(ticket.events.sole.actor).to be_nil
    end

    it 'records nothing for other changes, replies or touches' do
      ticket.update!(title: 'New title', body: 'New body')
      ticket.messages.create!(author: member, body: 'Hi')
      ticket.touch # rubocop:disable Rails/SkipsModelValidations

      expect(ticket.events).to be_empty
    end

    it 'restores the previous actor after with_actor' do
      Trailticket.with_actor(agent) { nil }

      expect(Trailticket::Current.actor).to be_nil
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
