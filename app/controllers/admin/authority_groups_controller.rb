class Admin::AuthorityGroupsController < ApplicationController
  include Hydra::AccessControlsEnforcement
  with_themed_layout '1_column'

  before_filter :verify_access
  before_action :set_authority_group, only: [:show, :edit, :update, :refresh]

  def index
    @admin_authority_groups = Admin::AuthorityGroup.all
  end

  def new
    @admin_authority_group = Admin::AuthorityGroup.new
  end

  def show
  end

  def create
   @admin_authority_group = Admin::AuthorityGroup.new(admin_authority_group_params)
   if @admin_authority_group.save
     @notice = 'Authority Group was successfully created.'
     redirect_to admin_authority_groups_path, notice: @notice
    else
      flash.now[:error] = 'Authority Group was not created.'
      render :new
    end
  end

  def edit
  end

  def update
    @admin_authority_group.assign_attributes(admin_authority_group_params)
    if valid_update? && @admin_authority_group.save
      @notice = 'Authority Group was successfully updated.'
      redirect_to admin_authority_group_path(@admin_authority_group), notice: @notice
    else
      flash.now[:error] = (Array.wrap(@notice) << 'Administrative Group was not updated.')
      render action: 'edit'
    end
  end

  def refresh
    @new_authorized_usernames = user_list_from_associated_group
    if !user_list_from_associated_group.empty? && authorized_users_changed?
      @admin_authority_group.authorized_usernames = @new_authorized_usernames
      if @admin_authority_group.save
        flash.now[:notice] = (Array.wrap(@notice) << 'User abilities refreshed for this Authority Group.')
      else
        flash.now[:error] = (Array.wrap(@notice) << 'User abilities were not saved.')
      end
    else
      flash.now[:notice] = (Array.wrap(@notice) << 'User abilities are unchanged.')
    end
    render action: 'show'
  end

  private

  def verify_access
    render 'errors/401' unless current_user.can? :manage, Admin::AuthorityGroup
  end

  def set_authority_group
    @admin_authority_group = Admin::AuthorityGroup.find(params[:id])
  end

  def admin_authority_group_params
    params.require(:admin_authority_group).permit(:auth_group_name, :description, :controlling_class_name, :associated_group_pid)
  end

  def valid_update?
    @notice = []
    @notice << "Please enter a valid group controlling class name." unless valid_class?(@admin_authority_group.controlling_class_name)
    @notice << "Please enter a valid group pid." unless @admin_authority_group.valid_group_pid?
    return false unless @notice.empty?
    true
  end

  def user_list_from_associated_group
    @admin_authority_group.reload_authorized_usernames.map {|a| %Q(#{a}) }.join(", ")
  end

  def authorized_users_changed?
    @admin_authority_group.authorized_usernames != @new_authorized_usernames
  end

  def valid_class?(name)
    begin
      name.constantize.is_a?(Class)
    rescue NameError
      false
    end
  end
end
