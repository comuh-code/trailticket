# frozen_string_literal: true

# Serves the interface's own CSS and JS, so it works whatever the host uses
# (Sprockets, Propshaft, importmap, a bundler or nothing) and under a strict CSP.
class Trailticket::Panel::AssetsController < Trailticket::Panel::ApplicationController
  TYPES = { '.css' => 'text/css', '.js' => 'text/javascript' }.freeze

  # Static public files with no data: the denied page needs them too, and the JS
  # is loaded by a <script> tag, which Rails' cross-origin JS check would block.
  skip_before_action :authorize_trailticket_web!
  skip_forgery_protection

  def show
    file = Trailticket::Web.root.join('assets', File.basename(params[:file].to_s))
    type = TYPES[file.extname]
    return head(:not_found) unless type && file.file?

    # URLs carry ?v=VERSION-DIGEST, so any change to the file busts the cache.
    current = params[:v] == web_asset_version(file.basename)
    expires_in(current ? 1.year : 5.minutes, public: true)
    send_file file, type: type, disposition: 'inline'
  end
end
