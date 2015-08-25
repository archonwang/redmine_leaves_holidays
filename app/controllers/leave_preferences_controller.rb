class LeavePreferencesController < ApplicationController
  unloadable
  include LeavesHolidaysLogic

  helper :leave_requests
  include LeaveRequestsHelper
  
  before_action :set_user
  before_action :set_user_preferences, except: [:index, :bulk_edit, :bulk_update]
  before_action :authenticate, except: [:show, :notification]
  before_action :set_holidays, only: [:new, :create, :edit, :bulk_edit, :update, :bulk_update]

  def index
    @users = LeavesHolidaysLogic.users_with_create_leave_request
  end

  def new
  	if @exists
      redirect_to edit_user_leave_preference_path
  	end
  end

  def create
  	@preference = LeavePreference.new(leave_preference_params) unless @exists
    @preference.user_id = @user_pref.id
  	if @preference.save
      event = LeaveEvent.new(user_id: @user.id, event_type: "user_pref_manual_create", comments: "{changed_by: #{User.current.id}, attributes: #{@preference.attributes}}")
      event.save
      flash[:notice] = "Preferences were sucessfully saved for user #{@user_pref.name}"
  		redirect_to edit_user_leave_preference_path
  	else
  		flash[:error] = "Invalid preferences"
  		render :new
  	end
  end

  def show
    render_403 unless LeavesHolidaysLogic.has_right(@user, @user_pref, @preference, :show)
  end

  def edit
  end

  def bulk_edit
    if params.has_key?(:user_ids)
      users = User.find(params[:user_ids])
      @users_preferences = users.map{|u| u.leave_preferences}
    else
      redirect_to leave_preferences_path
    end
  end

  def bulk_update
    users_preferences = User.find(params[:user_ids]).map{|u| u.leave_preferences}
    users_preferences.each do |user_pref|
      success = user_pref.update_attributes(params[:preferences].reject { |k,v| v.blank? })
      if !success 
        flash[:error] = "Invalid preferences"
        redirect_to :controller => 'leave_preferences', :action => 'bulk_edit', :user_ids => params[:user_ids] and return
      else
        event = LeaveEvent.new(user_id: @user.id, event_type: "user_pref_manual_update", comments: "{changed_by: #{User.current.id}, attributes: #{user_pref.attributes}}")
        event.save
      end
    end
    flash[:notice] = "Preferences were sucessfully updated"
    redirect_to leave_preferences_path
  end

  def update
    @preference.user_id = @user_pref.id
  	success = @preference.update(leave_preference_params)
      
    respond_to do |format|
      format.html { 
        if !success 
          flash[:error] = "Invalid preferences"
          render :edit
        else
          event = LeaveEvent.new(user_id: @user.id, event_type: "user_pref_manual_update", comments: "{changed_by: #{User.current.id}, attributes: #{@preference.attributes}}")
          event.save
          flash[:notice] = "Preferences were sucessfully updated for user #{@user_pref.name}"
          redirect_to edit_user_leave_preference_path
        end
      }
      format.js
    end
  end

  def destroy
    event = LeaveEvent.new(user_id: @user.id, event_type: "user_pref_deleted", comments: "{changed_by: #{User.current.id}, attributes: #{@preference.attributes}}")
    event.save
  	@preference.destroy
  	redirect_to new_user_leave_preference_path
  end

  def notification
    @vote_list = LeavesHolidaysLogic.vote_list(@user_pref)
    @manage_list = LeavesHolidaysLogic.manage_list(@user_pref)
  end


private

  def leave_preference_params
  	params.require(:leave_preference).permit(:user_id, :weekly_working_hours, :annual_leave_days_max, :region, :contract_start_date, :extra_leave_days, :is_contractor, :annual_max_comments, :leave_renewal_date)
  end

  def set_user
      @user = User.current
  end

  def set_user_preferences
      @user_pref = User.find(params[:user_id])
      @preference = @user_pref.leave_preferences
      @exists = (@preference.id != nil)
  end

  def set_holidays
	  @regions = LeavesHolidaysLogic.get_region_list
  end

  def authenticate
    unless action_name.in?(["index", "bulk_edit", "bulk_update"])
      unless LeavesHolidaysLogic.has_right(@user, @user_pref, @preference, params[:action].to_sym)
        redirect_to user_leave_preference_path
        return
      end
    else
      render_403 unless LeavesHolidaysLogic.has_manage_user_leave_preferences(@user)
    end
  end
end