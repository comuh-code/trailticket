# frozen_string_literal: true

RSpec.describe 'Trailticket API' do
  let(:member) { create(:admin, :member, name: 'Olivia') }
  let(:agent) { create(:admin, :agent, name: 'Sergio') }
  let(:guest) { create(:admin, :guest, name: 'Vera') }

  describe 'GET /trailticket/me' do
    it 'reports permissions for an author' do
      get '/trailticket/me', headers: auth(member)

      expect(json['permissions']).to eq('open' => true, 'manage' => false)
      expect(json['assignees']).to be_nil
    end

    it 'reports permissions and assignees for agent' do
      get '/trailticket/me', headers: auth(agent)

      expect(json.dig('permissions', 'manage')).to be(true)
      expect(json['assignees'].pluck('name')).to eq(['Sergio'])
    end
  end

  describe 'POST /trailticket/tickets' do
    it 'opens a ticket with context and screenshot' do
      post '/trailticket/tickets', as: :json, headers: auth(member), params: {
        ticket: {
          title: 'Checkout fails', body: 'Button does nothing', priority: 'high',
          context: {
            page: { url: 'https://app.test/checkout', title: 'Checkout' },
            trail: [{ type: 'click', label: 'button #buy' }],
            fields: [{ name: 'card_number', value: '4111' }, { name: 'plan', value: 'pro' }]
          },
          screenshot: png_data_url
        }
      }

      expect(response).to have_http_status(:created)
      expect(json['page_url']).to eq('https://app.test/checkout')
      expect(json['priority']).to eq('high')
      expect(json.dig('context', 'fields', 0, 'value')).to eq('[FILTERED]')
      expect(json.dig('context', 'fields', 1, 'value')).to eq('pro')
      expect(json['screenshot_url']).to eq("/trailticket/tickets/#{json['id']}/screenshot")

      get json['screenshot_url'], headers: auth(member)
      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq('image/png')
    end

    it 'returns errors for an invalid ticket' do
      post '/trailticket/tickets', as: :json, headers: auth(member),
                                   params: { ticket: { title: '' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig('errors', 'title')).to be_present
    end
  end

  describe 'GET /trailticket/tickets' do
    it 'forbids a guest' do
      get '/trailticket/tickets', headers: auth(guest)

      expect(response).to have_http_status(:forbidden)
      expect(json['error']).to eq('forbidden')
    end

    it 'lists only own tickets and hides others and their screenshots' do
      mine = create(:ticket, author: member)
      other = Trailticket.open_ticket(author: create(:admin, :member), title: 'X', body: 'Y',
                                      screenshot: png_data_url)

      get '/trailticket/tickets', headers: auth(member)
      expect(json['tickets'].pluck('id')).to eq([mine.id])
      expect(json.dig('meta', 'total')).to eq(1)

      get "/trailticket/tickets/#{other.id}", headers: auth(member)
      expect(response).to have_http_status(:forbidden)
      get "/trailticket/tickets/#{other.id}/screenshot", headers: auth(member)
      expect(response).to have_http_status(:forbidden)
    end

    it 'filters by status and paginates' do
      create_list(:ticket, 3, author: member)
      create(:ticket, author: member).close!(by: agent)

      get '/trailticket/tickets', headers: auth(agent)
      expect(json.dig('meta', 'total')).to eq(3)

      get '/trailticket/tickets?status=all&per=2&page=2', headers: auth(agent)
      expect(json.dig('meta', 'total')).to eq(4)
      expect(json['tickets'].size).to eq(2)

      get '/trailticket/tickets?status=closed', headers: auth(agent)
      expect(json.dig('meta', 'total')).to eq(1)
    end
  end

  describe 'managing a ticket' do
    let(:ticket) { create(:ticket, author: member) }
    let(:ticket_path) { "/trailticket/tickets/#{ticket.id}" }

    it 'does not let the author close or update' do
      post "#{ticket_path}/close", headers: auth(member)
      expect(response).to have_http_status(:forbidden)

      patch ticket_path, as: :json, headers: auth(member), params: { ticket: { status: 'closed' } }
      expect(response).to have_http_status(:forbidden)
      expect(ticket.reload).to be_status_open
    end

    it 'lets agent reply, write internal notes, assign and close' do
      post "#{ticket_path}/messages", as: :json, headers: auth(agent),
                                      params: { message: { body: 'Looking' } }
      expect(response).to have_http_status(:created)

      post "#{ticket_path}/messages", as: :json, headers: auth(agent),
                                      params: { message: { body: 'Secret', internal: true } }
      expect(json['internal']).to be(true)

      patch ticket_path, as: :json, headers: auth(agent),
                         params: { ticket: { status: 'in_progress', assignee_id: agent.id } }
      expect(response).to have_http_status(:success)
      expect(json.dig('assignee', 'name')).to eq('Sergio')

      get ticket_path, headers: auth(member)
      expect(json['messages'].pluck('body')).to eq(['Looking'])

      post "#{ticket_path}/close", headers: auth(agent)
      expect(json['status']).to eq('closed')
      expect(json.dig('closed_by', 'name')).to eq('Sergio')
    end

    it 'does not let authors post internal notes' do
      post "#{ticket_path}/messages", as: :json, headers: auth(member),
                                      params: { message: { body: 'Hi', internal: true } }
      expect(json['internal']).to be(false)
    end

    it 'does not assign someone outside the assignee list' do
      patch ticket_path, as: :json, headers: auth(agent),
                         params: { ticket: { assignee_id: guest.id } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(ticket.reload.assignee).to be_nil
    end
  end
end
