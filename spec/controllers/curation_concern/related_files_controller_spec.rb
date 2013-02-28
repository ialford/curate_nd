require 'spec_helper'

describe CurationConcern::RelatedFilesController do
  let(:parent_curation_concern) {
    FactoryGirl.create_curation_concern(:senior_thesis, user)
  }
  subject { FactoryGirl.create_generic_file(parent_curation_concern, user)}
  let(:user) { FactoryGirl.create(:user) }
  let(:another_user)  { FactoryGirl.create(:user) }
  let(:file) {Rack::Test::UploadedFile.new(__FILE__, 'text/plain', false)}
  it 'has a #parent_curation_concern' do
    controller.params[:parent_curation_concern_id] = parent_curation_concern.noid
    controller.parent_curation_concern.should == parent_curation_concern
  end

  it 'has a #curation_concern' do
    controller.curation_concern.should be_an_instance_of(GenericFile)
  end

  describe '#new' do
    it 'renders a form if you can edit the parent' do
      sign_in(user)
      parent_curation_concern
      get :new, parent_curation_concern_id: parent_curation_concern.to_param
      expect(response).to render_template('new')
    end

    it 'renders a form if you can edit the parent' do
      sign_in(another_user)
      parent_curation_concern
      get :new, parent_curation_concern_id: parent_curation_concern.to_param
      response.status.should == 302
      expect(response).to redirect_to(root_url)
    end
  end

  describe '#create' do
    xit 'attaches a singular file' do
      sign_in(user)
      parent_curation_concern
      expect {
        post(
          :create,
          parent_curation_concern_id: parent_curation_concern.to_param,
          related_file: { title: "Title", file: file }
        )
      }.to change { GenericFile.count }.by(1)
      expect(response).to(
        redirect_to(
          polymorphic_path([:curation_concern, parent_curation_concern])
        )
      )
    end
  end

end
