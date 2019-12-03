# Provides a simple API for retrieving ids of users who are permitted to act as
# a repository administrator.
class RepositoryAdministrator
  def self.auth_group_name
    'admin'
  end

  def self.authority_group
    @authority_group ||= Admin::AuthorityGroup.authority_group_for(auth_group_name: self.auth_group_name)
  end

  def self.initialize_usernames
    load_usernames
  end

  def self.usernames
   @usernames ||= self.authority_group.authorized_users
  end

  def self.include?(user_key)
    user_key = user_key.to_s
    !!usernames.include?(user_key)
  end

  def self.reload
     loaded_users = Admin::AuthorityGroup.reload_authority_group_users_for(auth_group_name: self.auth_group_name)
     @usernames = loaded_users unless loaded_users.empty?
     loaded_users
  end

  def self.clear_usernames
    @usernames = nil
  end

  private

  def self.load_usernames
    manager_usernames_config = Rails.root.join('config/admin_usernames.yml')
    if manager_usernames_config.exist?
      interpreted_config = YAML.load(ERB.new(manager_usernames_config.read).result)
      admin_usernames = interpreted_config.fetch(Rails.env).fetch('admin_usernames')
      Array.wrap(admin_usernames)
    else
      $stderr.puts "Unable to find admin_usernames file: #{manager_usernames_config}"
      []
    end
  end
end
