# frozen_string_literal: true

RSpec.describe Trailticket::ContextSanitizer do
  def sanitize(raw)
    described_class.call(raw)
  end

  it 'keeps known keys only' do
    out = sanitize(page: { url: 'https://a.test', title: 'Home', evil: 'x', nested: { a: 1 } },
                   extra: 'nope')
    expect(out).to eq('page' => { 'url' => 'https://a.test', 'title' => 'Home' })
  end

  it 'masks sensitive fields even if the browser did not' do
    out = sanitize(fields: [
                     { name: 'user[name]', value: 'Ana' },
                     { name: 'user[password]', value: 'hunter2' },
                     { name: 'doc', label: 'CPF', value: '123' },
                     { name: 'contact', value: 'x', masked: true },
                     { name: 'user[email]', value: 'a@b.c' }, # filter_parameters do app host
                     { name: 'pw', type: 'password', value: 's' }
                   ])
    values = out['fields'].to_h { |field| [field['name'], field['value']] }

    expect(values).to eq(
      'user[name]' => 'Ana',
      'user[password]' => '[FILTERED]',
      'doc' => '[FILTERED]',
      'contact' => '[FILTERED]',
      'user[email]' => '[FILTERED]',
      'pw' => '[FILTERED]'
    )
  end

  context 'when capture_field_values is disabled' do
    before { Trailticket.config.capture_field_values = false }
    after { Trailticket.config.capture_field_values = true }

    it 'drops field values entirely' do
      out = sanitize(fields: [{ name: 'q', value: 'hello' }])
      expect(out['fields'].first).to eq('name' => 'q', 'filled' => true, 'masked' => false)
    end
  end

  it 'filters sensitive query params in urls' do
    out = sanitize(trail: [{ type: 'visit',
                             url: 'https://a.test/r?reset_password_token=abc&page=2' }])
    expect(out['trail'].first['url'])
      .to eq('https://a.test/r?reset_password_token=%5BFILTERED%5D&page=2')
  end

  it 'caps lists and truncates strings' do
    out = sanitize(trail: Array.new(80) { |i| { type: 'click', label: 'x' * 1000, at: i.to_s } })

    expect(out['trail'].size).to eq(50)
    expect(out['trail'].last['at']).to eq('79')
    expect(out['trail'].first['label'].length).to be <= 501
  end

  it 'accepts a JSON string and ignores garbage' do
    expect(sanitize('{"page":{"title":"Home"}}').dig('page', 'title')).to eq('Home')
    expect(sanitize('not json')).to eq({})
    expect(sanitize(nil)).to eq({})
  end
end
