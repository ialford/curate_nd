require 'spec_helper'

describe Admin::IngestOsfArchivesController, type: :controller do
  let(:archive) { instance_double(Admin::IngestOSFArchive, valid?: true) }

  describe 'new' do
    let(:subject) { get :new }

    it 'assigns @archive' do
      allow(Admin::IngestOSFArchive).to receive(:new).and_return(archive)
      subject
      expect(assigns(:archive)).to eq(archive)
    end
  end

  describe '#create' do
    before(:each) do
      allow(OsfIngestWorker).to receive(:create_osf_job).with(archive).and_return(true)
    end

    let(:params) { { admin_ingest_osf_archive: { project_identifier: 'id' } } }
    let(:subject) { post :create, params }

    it 'assigns @archive' do
      allow(Admin::IngestOSFArchive).to receive(:new).and_return(archive)
      subject
      expect(assigns(:archive)).to eq(archive)
    end

    it 'uses build_with_id_or_url to create the new archive with the given params' do
      allow(Admin::IngestOSFArchive).to receive(:build_with_id_or_url).with(params[:admin_ingest_osf_archive]).and_return('archive')
      subject
      expect(assigns(:archive)).to eq('archive')
    end

    context 'when the parameters are valid' do
      before(:each) do
        allow(archive).to receive(:valid?).and_return(true)
        allow(Admin::IngestOSFArchive).to receive(:new).and_return(archive)
      end

      it 'uses OsfIngestWorker to create a job with the new archive' do
        expect(OsfIngestWorker).to receive(:create_osf_job).with(archive)
        subject
      end

      it 'redirects to the batch ingest controller, filtering to jobs named osfarchive' do
        expect(subject).to redirect_to(controller: 'batch_ingest', action: :index, params: { name_filter: 'osfarchive' })
      end
    end

    context 'when the parameters are invalid' do
      before(:each) do
        allow(archive).to receive(:valid?).and_return(false)
        allow(Admin::IngestOSFArchive).to receive(:new).and_return(archive)
      end

      it 'uses OsfIngestWorker to create a job with the new archive' do
        expect(OsfIngestWorker).not_to receive(:create_osf_job).with(archive)
        subject
      end

      it 're-renders new' do
        expect(subject).to render_template(:new)
      end
    end

    context 'when it fails to create the job' do
      before(:each) do
        allow(archive).to receive(:valid?).and_return(true)
        allow(Admin::IngestOSFArchive).to receive(:new).and_return(archive)
        allow(OsfIngestWorker).to receive(:create_osf_job).and_return(false)
      end

      it 're-renders new' do
        expect(subject).to render_template(:new)
      end
    end
  end
end
