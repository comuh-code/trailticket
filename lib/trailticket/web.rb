# frozen_string_literal: true

require 'haml'

module Trailticket
  module Panel
  end

  class Web < ::Rails::Engine
    isolate_namespace Trailticket::Panel
    engine_name 'trailticket_web'
    config.root = File.expand_path('../../web', __dir__)
  end
end
