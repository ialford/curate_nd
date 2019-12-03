class AddAuthorizedUsernamesToAuthorityGroups < ActiveRecord::Migration
  def change
    add_column :admin_authority_groups, :authorized_usernames, :string
  end
end
