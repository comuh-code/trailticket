# frozen_string_literal: true

class Trailticket::Panel::DesignSystemController < Trailticket::Panel::ApplicationController
  before_action { raise ActiveRecord::RecordNotFound unless Trailticket.config.web_design_system }

  COLOR_TOKENS = [
    %w[--tt-bg #f6f7f9 #0f1115 bg],
    %w[--tt-surface #ffffff #171a20 surface],
    %w[--tt-surface-2 #f0f2f5 #222631 surface_2],
    %w[--tt-column #eceff3 #13161b column],
    %w[--tt-text #1f2328 #e6e9ef text],
    %w[--tt-muted #59636e #9aa4b2 muted],
    %w[--tt-border #8c959f #6b7585 border],
    %w[--tt-line #1f23281a #ffffff1a line],
    %w[--tt-accent #2f5fd0 #7aa5ff accent],
    %w[--tt-accent-text #ffffff #0f1115 accent_text],
    %w[--tt-accent-soft #e3ebfc #1c2a45 accent_soft],
    %w[--tt-danger #c4312b #ff7a72 danger],
    %w[--tt-danger-soft #fdecea #3a1a19 danger_soft],
    %w[--tt-warning-soft #fff1dc #3a2710 warning_soft],
    %w[--tt-success #2e8540 #5cc36f success]
  ].freeze

  def show
    @color_tokens = COLOR_TOKENS
    @priorities = Trailticket::Ticket::PRIORITIES.reverse
    @statuses = Trailticket.config.statuses
  end
end
