# frozen_string_literal: true

RSpec.describe 'Trailticket web interface' do
  let(:agent) { create(:admin, :agent, name: 'Sergio') }
  let(:member) { create(:admin, :member, name: 'Olivia') }
  let(:community) { Community.create!(name: 'Centro') }

  def page
    response.parsed_body
  end

  def column(status)
    page.at_css(%([data-tt-column][data-status="#{status}"]))
  end

  def patch_status(ticket, status, as: :json, headers: auth(agent))
    patch "/chamados/tickets/#{ticket.id}/status",
          params: { status: status }, headers: headers, as: as
  end

  describe 'authorization' do
    it 'is denied by default' do
      default = Trailticket::Configuration.new.authorize
      allow(Trailticket.config).to receive(:authorize).and_return(default)

      get '/chamados', headers: auth(agent)

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include('Access denied')
      expect(page.at_css('[data-tt-board]')).to be_nil
    end

    it 'calls config.authorize with the request' do
      get '/chamados', headers: auth(member)
      expect(response).to have_http_status(:forbidden)

      get '/chamados'
      expect(response).to have_http_status(:forbidden)

      get '/chamados', headers: auth(agent)
      expect(response).to have_http_status(:ok)
    end

    it 'blocks every page and answers JSON requests with JSON' do
      ticket = create(:ticket)

      get "/chamados/tickets/#{ticket.id}", headers: auth(member)
      expect(response).to have_http_status(:forbidden)

      patch_status(ticket, 'closed', headers: auth(member))
      expect(response).to have_http_status(:forbidden)
      expect(json['error']).to eq('Access denied')
      expect(ticket.reload.status).to eq('open')
    end

    it 'serves its own CSS and JS, without authorization' do
      get '/chamados/assets/trailticket.css', params: { v: Trailticket::VERSION }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/css')
      expect(response.headers['Cache-Control']).to include('public')

      get '/chamados/assets/trailticket.js'
      expect(response.media_type).to eq('text/javascript')

      get '/chamados/assets/nope.css'
      expect(response).to have_http_status(:not_found)
    end

    it 'does not depend on the API permissions' do
      allow(Trailticket.config).to receive(:can_manage).and_return(->(_user) { false })

      get '/chamados', headers: auth(agent)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /chamados (board)' do
    it 'shows one column per status, with counters, cards and empty state' do
      create(:ticket, title: 'Login broken', priority: 'high', author: member, subject: community)
      create(:ticket, title: 'Slow page', author: member).update!(status: 'closed')

      get '/chamados', headers: auth(agent)

      expect(response).to have_http_status(:ok)
      expect(page.css('[data-tt-column]').pluck('data-status'))
        .to eq(%w[open in_progress waiting closed])

      open = column('open')
      expect(open.at_css('[data-tt-count]').text).to eq('1')
      expect(open.at_css('[data-tt-empty]')['hidden']).not_to be_nil
      card = open.at_css('[data-tt-card]')
      expect(card['draggable']).to eq('true')
      expect(card.text).to include('Login broken', 'Olivia', 'Centro', 'High')
      expect(card['data-url']).to match(%r{/chamados/tickets/\d+/status})

      expect(column('waiting').at_css('[data-tt-count]').text).to eq('0')
      expect(column('waiting').at_css('[data-tt-empty]')['hidden']).to be_nil
      expect(column('closed').text).to include('Slow page')
    end

    it 'uses the configured labels for authors and subjects' do
      allow(Trailticket.config).to receive_messages(
        author_label: ->(admin) { "Autor: #{admin.name}" },
        subject_label: ->(record) { "Comunidade #{record.name}" }
      )
      create(:ticket, author: member, subject: community)

      get '/chamados', headers: auth(agent)

      expect(column('open').text).to include('Autor: Olivia', 'Comunidade Centro')
    end

    it "loads the engine's own CSS and JS, not the app's" do
      get '/chamados', headers: auth(agent)

      expect(page.at_css('link[rel="stylesheet"]')['href'])
        .to eq("/chamados/assets/trailticket.css?v=#{Trailticket::VERSION}")
      expect(page.at_css('script[src]')['src'])
        .to eq("/chamados/assets/trailticket.js?v=#{Trailticket::VERSION}")
    end
  end

  describe 'GET /chamados/list' do
    before do
      create(:ticket, title: 'Checkout fails', priority: 'high')
      create(:ticket, title: 'Checkout slow', priority: 'low').update!(status: 'closed')
      create(:ticket, title: 'Login broken', priority: 'low')
    end

    def titles
      page.css('[data-tt-row] [data-tt-title]').map(&:text)
    end

    it 'lists every ticket' do
      get '/chamados/list', headers: auth(agent)

      expect(titles).to contain_exactly('Checkout fails', 'Checkout slow', 'Login broken')
      expect(page.at_css('[data-tt-total]').text).to eq('3 tickets')
    end

    it 'searches by title' do
      get '/chamados/list', params: { q: 'checkout' }, headers: auth(agent)

      expect(titles).to contain_exactly('Checkout fails', 'Checkout slow')
    end

    it 'treats the search as text, not as a LIKE pattern' do
      get '/chamados/list', params: { q: '%' }, headers: auth(agent)

      expect(titles).to be_empty
      expect(response.body).to include('No tickets match these filters.')
    end

    it 'filters by status and priority' do
      get '/chamados/list', params: { status: 'open', priority: 'low' }, headers: auth(agent)

      expect(titles).to eq(['Login broken'])
    end

    it 'ignores unknown filter values' do
      get '/chamados/list', params: { status: 'bogus', priority: 'nope' }, headers: auth(agent)

      expect(titles.size).to eq(3)
    end

    it 'paginates and keeps the filters in the links' do
      stub_const('Trailticket::Panel::TicketsController::PER_PAGE', 2)
      create(:ticket, title: 'Checkout again')

      get '/chamados/list', params: { q: 'checkout' }, headers: auth(agent)
      expect(titles.size).to eq(2)
      expect(page.at_css('[data-tt-page]').text).to eq('Page 1 of 2')
      expect(page.at_css('a[rel="next"]')['href']).to eq('/chamados/list?page=2&q=checkout')

      get '/chamados/list', params: { q: 'checkout', page: 2 }, headers: auth(agent)
      expect(titles.size).to eq(1)
      expect(page.at_css('a[rel="prev"]')['href']).to eq('/chamados/list?page=1&q=checkout')

      get '/chamados/list', params: { q: 'checkout', page: 99 }, headers: auth(agent)
      expect(page.at_css('[data-tt-page]').text).to eq('Page 2 of 2')
    end
  end

  describe 'GET /chamados/tickets/:id' do
    let(:ticket) do
      Trailticket.open_ticket(
        author: member, subject: community, title: 'Checkout fails', body: "Line 1\nLine 2",
        context: {
          page: { url: 'https://app.test/checkout?token=abc&step=2', title: 'Checkout' },
          trail: [
            { type: 'visit', url: 'https://app.test/plans', label: 'Plans',
              at: '2026-11-18T10:00:00Z' },
            { type: 'click', url: 'https://app.test/checkout', label: 'button #pay "Pay"' }
          ],
          fields: [{ name: 'card_number', value: '4111' }, { name: 'plan', value: 'pro' }]
        },
        metadata: { comuhub: { admin: 12, comunidade: { nome: 'Centro', plano: 'pro' } } }
      )
    end

    it 'shows the description, details, trail and the rest of the context' do
      get "/chamados/tickets/#{ticket.id}", headers: auth(agent)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Checkout fails', "Line 1\nLine 2", 'Olivia', 'Centro')

      page_url = page.at_css('[data-tt-page-url] a')
      expect(page_url['href']).to eq('https://app.test/checkout?token=%5BFILTERED%5D&step=2')
      expect(page_url['rel']).to include('noopener')

      trail = page.css('[data-tt-trail] li')
      expect(trail.size).to eq(2)
      expect(trail.first.at_css('a')['href']).to eq('https://app.test/plans')
      expect(trail.last.text).to include('button #pay "Pay"')

      context = page.at_css('[data-tt-context]')
      expect(context.css('dt').map(&:text))
        .to include('page', 'fields', 'comuhub', 'comunidade', 'nome')
      expect(context.text).to include('Centro', '[FILTERED]', 'pro')
      expect(context.text).not_to include('4111')
    end

    it 'offers a button for every other status' do
      get "/chamados/tickets/#{ticket.id}", headers: auth(agent)

      buttons = page.css('[data-tt-status-actions] form')
      expect(buttons.map { |f| f.at_css('input[name="status"]')['value'] })
        .to eq(%w[in_progress waiting closed])
      expect(buttons.first['action']).to eq("/chamados/tickets/#{ticket.id}/status")
      expect(buttons.first.at_css('input[name="_method"]')['value']).to eq('patch')
    end

    it "renders the app's own context partial when configured" do
      allow(Trailticket.config).to receive(:context_partial).and_return('dummy/ticket_context')

      get "/chamados/tickets/#{ticket.id}", headers: auth(agent)

      expect(page.at_css('[data-dummy-context]').text).to include("Ticket #{ticket.id}")
    end

    it 'returns 404 for an unknown ticket' do
      get '/chamados/tickets/0', headers: auth(agent)

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('Ticket not found')
    end
  end

  describe 'PATCH /chamados/tickets/:id/status' do
    let(:ticket) { create(:ticket, author: member) }

    it 'changes the status from the board (JSON)' do
      patch_status(ticket, 'in_progress')

      expect(response).to have_http_status(:ok)
      expect(json).to eq('id' => ticket.id, 'status' => 'in_progress')
      expect(ticket.reload.status).to eq('in_progress')
    end

    it 'redirects back to the ticket from the status buttons (HTML)' do
      patch_status(ticket, 'waiting', as: nil)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to("/chamados/tickets/#{ticket.id}")
      expect(ticket.reload.status).to eq('waiting')
    end

    it 'fills closed_by with current_actor when closing and clears it when reopening' do
      patch_status(ticket, 'closed')

      ticket.reload
      expect(ticket.closed_by).to eq(agent)
      expect(ticket.closed_at).to be_present

      get "/chamados/tickets/#{ticket.id}", headers: auth(agent)
      expect(page.at_css('[data-tt-closed-by]').text).to eq('Sergio')

      patch_status(ticket, 'open')

      ticket.reload
      expect(ticket.closed_by).to be_nil
      expect(ticket.closed_at).to be_nil
    end

    it 'rejects an invalid status with 422 and does not save (JSON)' do
      patch_status(ticket, 'archived')

      expect(response).to have_http_status(:unprocessable_content)
      expect(json['error']).to eq('“archived” is not a valid status')
      expect(ticket.reload.status).to eq('open')
    end

    it 'rejects an invalid status with 422 and shows the error (HTML)' do
      patch_status(ticket, '', as: nil)

      expect(response).to have_http_status(:unprocessable_content)
      expect(page.at_css('[data-tt-error]').text)
        .to eq('Status not changed: “” is not a valid status')
      expect(page.at_css('[data-tt-status-actions] [aria-current]').text).to eq('Open')
      expect(ticket.reload.status).to eq('open')
    end

    it 'calls on_status_changed' do
      calls = []
      allow(Trailticket.config).to receive(:on_status_changed)
        .and_return(->(t, from, to) { calls << [t.id, from, to] })

      patch_status(ticket, 'closed')

      expect(calls).to eq([[ticket.id, 'open', 'closed']])
    end

    context 'with forgery protection on' do
      around do |example|
        ActionController::Base.allow_forgery_protection = true
        example.run
      ensure
        ActionController::Base.allow_forgery_protection = false
      end

      it 'rejects a request without the CSRF token' do
        expect { patch_status(ticket, 'closed') }
          .to raise_error(ActionController::InvalidAuthenticityToken)
        expect(ticket.reload.status).to eq('open')
      end

      it 'accepts the token from the page' do
        get '/chamados', headers: auth(agent)
        token = page.at_css('meta[name="csrf-token"]')['content']

        patch_status(ticket, 'closed', headers: auth(agent).merge('X-CSRF-Token' => token))

        expect(response).to have_http_status(:ok)
        expect(ticket.reload.status).to eq('closed')
      end
    end
  end

  describe 'POST /chamados/tickets/:id/messages (replies)' do
    let(:ticket) { create(:ticket, author: member) }

    def reply(headers: auth(agent), **params)
      post "/chamados/tickets/#{ticket.id}/messages", params: params, headers: headers
    end

    it 'adds a public reply by current_actor and goes back to it' do
      reply(body: 'We are on it')

      message = ticket.messages.sole
      expect(message).to have_attributes(body: 'We are on it', internal: false, author: agent)
      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to("/chamados/tickets/#{ticket.id}#message-#{message.id}")
    end

    it 'adds an internal note when checked' do
      reply(body: 'Looks like the deploy', internal: '1')

      expect(ticket.messages.sole.internal).to be(true)
    end

    it 'rejects an empty reply with 422, keeping the form' do
      reply(body: '   ', internal: '1')

      expect(response).to have_http_status(:unprocessable_content)
      expect(page.at_css('[data-tt-reply-error]').text).to eq('Write something before sending.')
      expect(page.at_css('[data-tt-reply] input[name="internal"]')['checked']).not_to be_nil
      expect(ticket.messages).to be_empty
    end

    it 'explains when current_actor is not configured' do
      allow(Trailticket.config).to receive(:current_actor).and_return(->(_request) {})

      reply(body: 'Hello')

      expect(response).to have_http_status(:unprocessable_content)
      expect(page.at_css('[data-tt-reply-error]').text).to include('config.current_actor')
      expect(page.at_css('[data-tt-reply] textarea').text).to eq('Hello')
      expect(ticket.messages).to be_empty
    end

    it 'is denied without authorization' do
      reply(body: 'Hi', headers: auth(member))

      expect(response).to have_http_status(:forbidden)
      expect(ticket.messages).to be_empty
    end

    it 'calls on_message_created' do
      created = []
      allow(Trailticket.config).to receive(:on_message_created)
        .and_return(->(message) { created << message.body })

      reply(body: 'Hi')

      expect(created).to eq(['Hi'])
    end

    it "does not touch the app's own Message model" do
      Message.create!(text: 'from the app')

      reply(body: 'from the panel')

      expect(Message.pluck(:text)).to eq(['from the app'])
      expect(Trailticket::Message.pluck(:body)).to eq(['from the panel'])
    end

    context 'with forgery protection on' do
      around do |example|
        ActionController::Base.allow_forgery_protection = true
        example.run
      ensure
        ActionController::Base.allow_forgery_protection = false
      end

      it 'requires the CSRF token' do
        expect { reply(body: 'Hi') }.to raise_error(ActionController::InvalidAuthenticityToken)
      end
    end
  end

  describe 'ticket history' do
    let(:ticket) { create(:ticket, author: member, title: 'Checkout fails') }

    def entries
      page.css('[data-tt-history] [data-tt-entry]').map do |li|
        [li['data-tt-entry'], li.at_css('.tt-timeline-text, .tt-body').text.squish]
      end
    end

    it 'shows opening, moves, priority, assignee, replies and notes in order' do
      patch_status(ticket, 'in_progress')
      post "/chamados/tickets/#{ticket.id}/messages",
           params: { body: 'On it' }, headers: auth(agent)
      Trailticket.with_actor(agent) { ticket.reload.update!(priority: 'urgent', assignee: agent) }
      post "/chamados/tickets/#{ticket.id}/messages",
           params: { body: 'Deploy issue', internal: '1' }, headers: auth(agent)
      patch_status(ticket, 'closed')
      patch_status(ticket, 'open')

      get "/chamados/tickets/#{ticket.id}", headers: auth(agent)

      expected = [
        ['created', 'Olivia opened the ticket'],
        ['status_changed', 'Sergio moved it from Open to In progress'],
        ['message', 'On it'],
        ['priority_changed', 'Sergio changed the priority from Normal to Urgent'],
        ['assignee_changed', 'Sergio changed the assignee from — to Sergio'],
        ['note', 'Deploy issue'],
        ['status_changed', 'Sergio closed the ticket (In progress → Closed)'],
        ['status_changed', 'Sergio reopened the ticket (Closed → Open)']
      ]
      expect(entries).to eq(expected)
    end

    it 'records changes made through the JSON API as the signed-in user' do
      patch "/trailticket/tickets/#{ticket.id}", as: :json, headers: auth(agent),
                                                 params: { ticket: { status: 'waiting' } }

      expect(ticket.events.sole).to have_attributes(action: 'status_changed', actor: agent)
    end

    it 'shows unknown actors and removed assignees without failing' do
      ticket.update!(status: 'waiting')
      ticket.events.create!(action: 'assignee_changed',
                            data: { 'from' => { 'type' => 'Admin', 'id' => 0 }, 'to' => nil })

      get "/chamados/tickets/#{ticket.id}", headers: auth(agent)

      expect(entries).to include(
        ['status_changed', 'Someone moved it from Open to Waiting'],
        ['assignee_changed', 'Someone changed the assignee from Admin #0 to —']
      )
    end
  end

  describe 'escaping' do
    let!(:ticket) do
      Trailticket.open_ticket(
        author: member,
        title: '<script>alert("title")</script>',
        body: '<img src=x onerror=alert(1)>',
        context: {
          page: { url: 'javascript:alert(1)', title: '<b>bold</b>' },
          trail: [{ type: 'click', url: 'JaVaScRiPt:alert(2)', label: '<svg onload=alert(3)>' },
                  { type: 'visit', url: ' javascript:alert(5)', label: 'spaced' }]
        },
        metadata: { extra: { html: '<iframe src=x></iframe>', link: 'javascript:alert(4)' } }
      )
    end

    before do
      allow(Trailticket.config).to receive(:author_label)
        .and_return(->(_admin) { '<em>author</em>' })
      ticket.messages.create!(author: agent, body: '<script>alert("reply")</script>')
      Trailticket.with_actor(agent) { ticket.update!(status: 'waiting') }
    end

    it 'escapes user text and never links javascript: URLs on any page' do
      ['/chamados', '/chamados/list', "/chamados/tickets/#{ticket.id}"].each do |path|
        get path, headers: auth(agent)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('<script>alert', '<img src=x', '<svg onload',
                                             '<iframe', '<b>bold</b>', '<em>author</em>')
        expect(response.body).to include('&lt;script&gt;alert(&quot;title&quot;)&lt;/script&gt;')
        hrefs = page.css('a[href]').map { |a| a['href'].strip.downcase }
        expect(hrefs.grep(/\Ajavascript:/)).to be_empty, "#{path}: #{hrefs.inspect}"
      end
    end

    it 'shows javascript: URLs as plain text' do
      get "/chamados/tickets/#{ticket.id}", headers: auth(agent)

      expect(page.at_css('[data-tt-page-url]').text).to eq('javascript:alert(1)')
      expect(page.at_css('[data-tt-page-url] a')).to be_nil
      expect(page.at_css('[data-tt-trail]').text).to include('JaVaScRiPt:alert(2)')
    end
  end

  describe 'custom statuses' do
    before do
      allow(Trailticket.config).to receive(:statuses).and_return(%w[novo andamento resolvido])
    end

    it 'uses them as columns and treats the last one as final' do
      ticket = create(:ticket, author: member)
      expect(ticket.status).to eq('novo')

      get '/chamados', headers: auth(agent)
      expect(page.css('[data-tt-column]').pluck('data-status'))
        .to eq(%w[novo andamento resolvido])

      patch_status(ticket, 'open')
      expect(response).to have_http_status(:unprocessable_content)

      patch_status(ticket, 'resolvido')
      expect(ticket.reload.closed_by).to eq(agent)
      expect(Trailticket::Ticket.active).to be_empty
    end
  end
end
