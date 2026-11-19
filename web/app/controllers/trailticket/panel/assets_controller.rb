# frozen_string_literal: true

class Trailticket::Panel::AssetsController < Trailticket::Panel::ApplicationController
  TYPES = { '.css' => 'text/css', '.js' => 'text/javascript' }.freeze

  skip_before_action :authorize_trailticket_web!
  skip_forgery_protection

  def show
    file = Trailticket::Web.root.join('assets', File.basename(params[:file].to_s))
    type = TYPES[file.extname]
    return head(:not_found) unless type && file.file?

    current = params[:v] == web_asset_version(file.basename)
    expires_in(current ? 1.year : 5.minutes, public: true)
    send_file file, type: type, disposition: 'inline'
  end
end
