require 'spec_helper'

describe TemporaryAccessToken do
  subject { FactoryGirl.build(:temporary_access_token) }

  it 'can report how long tokens are valid after first use' do
    expect(described_class.hours_until_expiry).to be_kind_of(Integer)
  end

  context 'test support' do
    it 'has a valid factory' do
      expect(subject).to be_valid
    end
  end

  context 'when being created' do
    context 'without a provided SHA' do
      subject { FactoryGirl.build(:temporary_access_token, sha: nil) }

      it 'permits a null SHA during object initialization' do
        expect(subject.sha).to eq(nil)
      end

      it 'sets a SHA during object persistence' do
        subject.save!
        expect(subject.sha).not_to eq(nil)
      end
    end

    it 'ignores SHA values passed during object initialization' do
      provided_sha = 'please_ignore_this_sha'
      subject.sha = provided_sha
      subject.save!
      expect(subject.sha).not_to eq(provided_sha)
    end

    it 'ignores pid namespace passed during object initialization' do
      subject.noid = 'und:1234'
      noid_from_pid = '1234'
      subject.save!
      expect(subject.noid).to eq(noid_from_pid)
    end
  end

  context 'when validating existing tokens' do
    it 'should allow access to existing, unused tokens' do
      subject.save!
      expect(described_class.count).not_to eq(0)
      expect(subject.expiry_date).to be_nil
      expect(described_class.permitted?(subject.noid, subject.sha)).to eq(true)
    end

    it 'should set a expiry date the first time it has been used' do
      subject.save!
      expect(subject.expiry_date).to be_nil
      expect(described_class.use!(subject.sha)).to eq(true)
      updated_token = described_class.find(subject.sha)
      expect(updated_token.expiry_date).to_not be_nil
    end

    it 'should not change a set expiry date if the token is used' do
      a_time_in_the_future = Time.now + 1.hour
      subject.expiry_date = a_time_in_the_future
      subject.save!
      expect(described_class.use!(subject.sha)).to eq(false)
      expect(subject.expiry_date).to eq(a_time_in_the_future)
    end

    it 'should repeatedly permit access with a token before the expiry period has elapsed' do
      subject.expiry_date = Time.now + 1.hour
      subject.save!
      expect(described_class.permitted?(subject.noid, subject.sha)).to eq(true)
      expect(described_class.permitted?(subject.noid, subject.sha)).to eq(true)
    end

    it 'should not permit access with a token after the expiry date has elapsed' do
      subject.expiry_date = Time.now - 1.hour
      subject.save!
      expect(described_class.permitted?(subject.noid, subject.sha)).to eq(false)
    end

    it 'should not be able to update the expiry date of a token with an unknown sha' do
      expect(described_class.use!('sha_that_does_not_exist')).to eq(false)
    end
  end

  context 'when updating existing tokens' do
    it 'should accept a "reset" flag' do
      subject.reset_expiry_date = true
      subject.save!
    end

    it 'should reset the expiry date if the "reset" flag is passed' do
      subject.expiry_date = Time.now
      subject.save!
      subject.reset_expiry_date = true
      subject.save!
      expect(subject.expiry_date).to be_nil
    end
  end

  describe 'revoke!' do
    it 'should set the expiry date to now' do
      subject.revoke!
      expect(subject.expiry_date.to_date).to eq(Date.today)
    end
  end

  describe '#obsolete?' do
    context 'when valid' do
      before do
        allow(subject).to receive(:expiry_date).and_return(nil)
        allow(subject).to receive(:updated_at).and_return(Time.now - 10.days)
      end

      it 'is not reported as obsolete' do
        expect(subject.obsolete?).to eq(false)
      end
    end
    context 'when expired' do
      before do
        allow(subject).to receive(:expiry_date).and_return(Time.now - 28.hours)
      end

      it 'is obsolete if over a day old' do
        expect(subject.obsolete?).to eq(true)
      end
    end
    context 'when unused' do
      before do
        allow(subject).to receive(:expiry_date).and_return(nil)
        allow(subject).to receive(:updated_at).and_return(Time.now - 91.days)
      end

      it 'is obsolete if not modified in past 90 days' do
        expect(subject.obsolete?).to eq(true)
      end
    end
  end

  describe 'token renewal requests' do
    let(:token_sha) { subject.sha }
    let(:validation) { TemporaryAccessToken.access_request_allowed_for?(token_sha) }
    let(:request) { TemporaryAccessToken.build_renewal_request_for(token_sha) }
    let(:etd) { double('Etd', class: Etd, human_readable_type: "Etd") }
    let(:document) { double('Document', class: Document, human_readable_type: "Document") }
    let(:file) { Tempfile.new('test') }
    let(:etd_request_html) { "      <a class=\"btn btn-default\" href=\"mailto:dteditor@nd.edu?subject=[Etd%20Access%20Request]%20Renewed%20Access%20to%20File%20(id:%20a1b2c3d4)&body=Previously,%20I%20had%20been%20granted%20temporary%20access%20to%20a%20restricted%20file%20in%20CurateND%20(id:%20a1b2c3d4).%20I%20no%20longer%20have%20access%20to%20the%20file%20and%20would%20like%20to%20view%20it%20again.%0A%0AHere%20is%20the%20access%20token%20I%20was%20given:%0A%20scaxnVc5inR_DKZlpsce4KznPQ\">Request an Access Extension</a>\n" }

    before do
      allow(TemporaryAccessToken).to receive(:find).with(token_sha).and_return(subject)
      allow(subject).to receive(:token_file).and_return(file)
    end

    context 'for etd (data in config/access_request_map.yml)' do
      before do
        allow(file).to receive(:parent).and_return(etd)
      end

      it 'validates access requests as true' do
        expect(validation).to eq(true)
      end
      it 'builds renewal request' do
        expect(request).to eq(etd_request_html)
      end
    end

    context 'for document (data in config/access_request_map.yml)' do
      before do
        allow(file).to receive(:parent).and_return(document)
      end

      it 'validates access requests as false' do
        expect(validation).to eq(false)
      end
    end
  end
end
