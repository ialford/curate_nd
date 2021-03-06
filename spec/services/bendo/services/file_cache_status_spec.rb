require 'fast_spec_helper'
require 'rspec/its'
require 'bendo/services/fake_api'
require 'bendo/services/file_cache_status'

module Bendo
  module Services
    RSpec.describe FileCacheStatus do
      describe '.call' do
        context 'with no identifiers' do
          subject { described_class.call(handler: FakeApi) }
          its(:body) { is_expected.to eq({}) }
          its(:status) { is_expected.to eq(200) }
        end

        context 'with a single identifier' do
          subject { described_class.call(item_slugs: '1001001001', handler: FakeApi) }
          its(:body) { is_expected.to be_kind_of(Hash) }
          its(:body) { is_expected.to include('1001001001') }
          its(:status) { is_expected.to eq(200) }
        end

        context 'with an Array of identifiers' do
          subject { described_class.call(item_slugs: ['1001001001', 'Masks'], handler: FakeApi) }
          its(:body) { is_expected.to be_kind_of(Hash) }
          its(:body) { is_expected.to include('1001001001') }
          its(:body) { is_expected.to include('Masks') }
          its(:status) { is_expected.to eq(200) }
        end
      end
    end
  end
end
