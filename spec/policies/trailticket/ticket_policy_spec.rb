# frozen_string_literal: true

RSpec.describe Trailticket::TicketPolicy do
  context 'when the user is a member' do
    subject(:policy) { described_class.new(create(:admin, :member)) }

    it { is_expected.to be_create }
    it { is_expected.not_to be_manage }
  end

  context 'when the user is an agent' do
    subject(:policy) { described_class.new(create(:admin, :agent)) }

    it { is_expected.to be_create }
    it { is_expected.to be_manage }
  end

  it 'gives no access to other roles and guests' do
    expect(described_class.new(create(:admin, :guest))).not_to be_access
    expect(described_class.new(nil)).not_to be_access
  end

  describe 'with a ticket' do
    let(:member) { create(:admin, :member) }
    let(:ticket) { create(:ticket, author: member) }

    it 'lets authors see their own ticket only' do
      expect(described_class.new(member, ticket)).to be_show
      expect(described_class.new(create(:admin, :member, name: 'Other'), ticket)).not_to be_show
      expect(described_class.new(create(:admin, :agent), ticket)).to be_show
    end

    it 'does not let authors reply to a closed ticket' do
      ticket.close!(by: create(:admin, :agent))
      expect(described_class.new(member, ticket)).not_to be_reply
    end
  end

  describe described_class::Scope do
    let(:member) { create(:admin, :member) }
    let!(:mine) { create(:ticket, author: member) }

    before { create(:ticket, author: create(:admin, :member)) }

    it 'resolves by role' do
      expect(described_class.new(member).resolve).to contain_exactly(mine)
      expect(described_class.new(create(:admin, :agent)).resolve.count).to eq(2)
      expect(described_class.new(create(:admin, :guest)).resolve).to be_empty
    end
  end
end
