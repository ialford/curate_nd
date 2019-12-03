###############################################################################
###############################################################################
####
####
####  ATTENTION: db/seeds.rb should be something that can be run repeatedly
####    without duplicating data on the underlying application.
####
####
###############################################################################
###############################################################################

# Initialize authority groups if they don't already exist

# Create super administrators from yml
super_administrators = Admin::SuperAdmin.initialize_usernames
users_to_authorize = super_administrators.map {|a| %Q(#{a}) }.join(", ")

super_admin = Admin::AuthorityGroup.create_with(description: 'Authority Control Group', authorized_usernames: users_to_authorize).find_or_create_by(auth_group_name: 'super_admin', controlling_class_name: "Admin::SuperAdmin")

# Create administrators from yml
administrators = RepositoryAdministrator.initialize_usernames
users_to_authorize = administrators.map {|a| %Q(#{a}) }.join(", ")

administrators.each do |username|
  next if RepoManager.find_by(username: username)
  RepoManager.find_or_create_by!(username: username, active: true)
end

admin = Admin::AuthorityGroup.create_with(description: 'Users with admin access rights', authorized_usernames: users_to_authorize).find_or_create_by(auth_group_name: 'admin', controlling_class_name: "RepositoryAdministrator")
