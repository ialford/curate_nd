class CurationConcern::ImagesController < CurationConcern::GenericWorksController
  self.curation_concern_type = Image

  def setup_form
    if action_name == 'new'
      curation_concern.creator << current_user.name if curation_concern.creator.empty? && !current_user.can_make_deposits_for.any?
      curation_concern.editors << current_user.person unless curation_concern.editors.present?
    end
    curation_concern.editors.build
    curation_concern.editor_groups.build
    curation_concern.viewers.build
    curation_concern.viewer_groups.build
  end
end
