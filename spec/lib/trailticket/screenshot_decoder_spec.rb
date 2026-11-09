# frozen_string_literal: true

RSpec.describe Trailticket::ScreenshotDecoder do
  def decode(input)
    described_class.call(input)
  end

  it 'decodes a PNG data URL' do
    out = decode(png_data_url)

    expect(out[:content_type]).to eq('image/png')
    expect(out[:filename]).to end_with('.png')
    expect(out[:io].read).to start_with("\x89PNG".b)
  end

  it 'rejects disallowed types and mismatched content' do
    expect { decode(data_url('image/svg+xml', '<svg/>')) }
      .to raise_error(Trailticket::InvalidScreenshot)
    expect { decode(data_url('image/png', 'GIF89a')) }.to raise_error(Trailticket::InvalidScreenshot)
    expect { decode('not a data url') }.to raise_error(Trailticket::InvalidScreenshot)
  end

  context 'when the image is over max_screenshot_bytes' do
    before { Trailticket.config.max_screenshot_bytes = 10 }
    after { Trailticket.config.max_screenshot_bytes = 5 * 1024 * 1024 }

    it 'rejects it' do
      expect { decode(png_data_url) }.to raise_error(Trailticket::InvalidScreenshot)
    end
  end

  it 'treats blank input as no screenshot' do
    expect(decode(nil)).to be_nil
    expect(decode('')).to be_nil
  end
end
