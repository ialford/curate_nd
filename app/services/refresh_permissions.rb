class RefreshPermissions
  # reset the cached value for each authority group's usernames
  def self.reinitialize
    Admin::AuthorityGroup.all.each do |group|
      group.controlling_class_name.constantize.clear_usernames
    end
  end
end
