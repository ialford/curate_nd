module Admin
  class SuperAdmin
    def self.auth_group_name
      'super_admin'
    end

    def self.authority_group
      @authority_group ||= Admin::AuthorityGroup.authority_group_for(auth_group_name: self.auth_group_name)
    end

    def self.usernames
     @usernames ||= self.authority_group.authorized_users
    end

    def self.include?(user_key)
      user_key = user_key.to_s
      !!usernames.include?(user_key)
    end

    def self.reload
      loaded_users = AuthorityGroup.reload_authority_group_users_for(auth_group_name: self.auth_group_name)
      @usernames = loaded_users unless loaded_users.empty?
      loaded_users
    end

    def self.initialize_usernames
      load_usernames
    end

    def self.clear_usernames
      @usernames = nil
    end

    private

    def self.load_usernames
      super_config = Rails.root.join('config/super_admin.yml')
      if super_config.exist?
        interpreted_config = YAML.load(ERB.new(super_config.read).result)
        super_admin_usernames = interpreted_config.fetch(Rails.env).fetch('super_admin_usernames')
        Array.wrap(super_admin_usernames)
      else
        $stderr.puts "Unable to find super_admin_usernames file: #{super_config}"
        []
      end
    end
  end
end
