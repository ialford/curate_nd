class CreateAuthorityGroups < ActiveRecord::Migration
  def change
    create_table :admin_authority_groups do |t|
      t.string :auth_group_name, null: false
      t.text :description
      t.string :controlling_class_name
      t.string :associated_group_pid

      t.timestamps
    end

    add_index :admin_authority_groups, :auth_group_name, unique: true
    add_index :admin_authority_groups, :associated_group_pid
  end

  def self.down
    drop_table :admin_authority_groups
  end
end
