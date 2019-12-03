module Admin
  class AuthorityGroup < ActiveRecord::Base
    validates :auth_group_name, presence: true
    validates :description, presence: true

    # find authorized users from this AuthorityGroup.
    # TODO: Do we want to set up caching for this?
    def authorized_users
      @members ||= authorized_usernames.split(', ')
    end

    def reload_authorized_usernames
      return authorized_users if controlling_class_name.nil?
      controlling_class_name.constantize.reload
    end

    def valid_group_pid?
      return true if associated_group_pid.empty?
      return true unless associated_group.nil?
      false
    end

    def associated_group
      begin
        @associated_group ||= Hydramata::Group.find(associated_group_pid)
      rescue
        return nil
      end
      @associated_group
    end

    # reload users from associated Hydramata::Group if one exists
    def self.reload_authority_group_users_for(auth_group_name:)
      auth_group = authority_group_for(auth_group_name: auth_group_name)
      return [] if auth_group.nil?
      return [] if auth_group.associated_group.nil?
      @members = []
      auth_group.associated_group.members.each do |person|
        @members << person.user.username
      end
      @members
    end

    def self.authority_group_for(auth_group_name:)
      begin
        auth_group = AuthorityGroup.find_by(auth_group_name: auth_group_name)
      rescue
        nil
      end
      auth_group
    end
  end
end
