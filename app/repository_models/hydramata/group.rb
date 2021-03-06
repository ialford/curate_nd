class Hydramata::Group < ActiveFedora::Base
  include Sufia::ModelMethods
  include Hydra::ModelMethods
  include CurationConcern::HumanReadableType
  include Hydra::AccessControls::Permissions
  include Sufia::Noid

  has_metadata 'properties', type: Curate::PropertiesDatastream
  has_attributes :relative_path, :depositor, :owner, datastream: :properties, multiple: false
  class_attribute :human_readable_short_description

  has_and_belongs_to_many :members, class_name: "::Person", property: :has_member, inverse_of: :is_member_of
  has_many :works, property: :has_editor_group, class_name: "ActiveFedora::Base"
  has_many :view_works, property: :has_viewer_group, class_name: "ActiveFedora::Base"
  before_destroy :remove_associations
  has_metadata "descMetadata", type: GroupMetadataDatastream
  accepts_nested_attributes_for :members, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :works, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :view_works, allow_destroy: true, reject_if: :all_blank

  has_attributes :title, :date_uploaded, :date_modified, :description, datastream: :descMetadata, multiple: false
  validates :title, presence: true

  def add_member(candidate, role='')
    return if(!candidate.is_a?(Person) or self.members.include?(candidate))
    self.add_relationship(:has_member, candidate)
    self.save!
    candidate.add_relationship(:is_member_of, self)
    candidate.save!
    self.create_role(candidate, role)
  end

  def remove_member(candidate)
    return if !self.members.include?(candidate)
    return if( ( self.edit_users.include?(candidate.user_key) ) && ( self.edit_users.size == 1 ) )
    remove_candidate_member(candidate)
  end

  def remove_candidate_member(candidate)
    candidate.remove_relationship(:is_member_of, self)
    candidate.save!
    self.remove_relationship(:has_member, candidate)
    self.save!
    self.remove_member_privileges(candidate)
  end

  def to_s
    title
  end

  def can_be_member_of_collection?(collection)
    false
  end

  def create_role(candidate, role)
    if role == 'manager'
      self.group_edit_membership(candidate)
    else
      self.group_read_membership(candidate)
    end
  end

  def group_edit_membership(candidate)
    if self.edit_users.include?(candidate.user_key)
      return
    end
    self.read_users.delete(candidate.user_key) if self.read_users.include?(candidate.user_key)
    self.permissions_attributes = [{name: candidate.user_key, access: "edit", type: "person"}]
    self.save!
  rescue ActiveFedora::RecordInvalid => e
    errors.add(:title, e.message)
  end

  def group_read_membership(candidate)
    if( ( self.edit_users.include?(candidate.user_key) ) && ( self.edit_users.size == 1 ) )
      return
    end
    self.edit_users.delete(candidate.user_key) if self.edit_users.include?(candidate.user_key)
    self.permissions_attributes = [{name: candidate.user_key, access: "read", type: "person"}]
    self.save!
  end

  def remove_member_privileges(candidate)
    if( ( self.edit_users.include?(candidate.user_key) ) && ( self.edit_users.size == 1 ) )
      return
    end
    self.edit_users = self.edit_users - [candidate.user_key] if self.edit_users.include?(candidate.user_key)
    self.read_users = self.read_users - [candidate.user_key] if self.read_users.include?(candidate.user_key)
    self.save!
  end

  def owner?(member)
    # check if member is an object or just an id obtained by javascript
    if member.respond_to?(:user_key)
      edit_users.include?(member.user_key) ? member.pid : '0'
    else
      edit_users.include?(member) ? member : '0'
    end
  end

  private

  def remove_associations
    remove_members
    remove_works
    remove_privileges
  end

  def remove_privileges_on_work(work)
    work.edit_groups = work.edit_groups - [self.pid] if work.edit_groups.include?(self.pid)
    work.read_groups = work.read_groups - [self.pid] if work.read_groups.include?(self.pid)
    work.save!
  end

  def remove_members
    self.members.each do |member|
      self.remove_candidate_member(member)
    end
  end

  def remove_works
    self.works.each do |work|
      work.remove_record_editor_group(self)
    end

    self.view_works.each do |work|
      work.remove_record_viewer_group(self)
    end
  end

  def remove_privileges
    self.works.each do |work|
      remove_privileges_on_work(work)
    end
  end
end
