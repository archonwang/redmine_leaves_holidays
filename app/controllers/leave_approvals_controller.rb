class LeaveApprovalsController < ApplicationController
  unloadable
  include LeavesHolidaysLogic
  include LeavesHolidaysDates
  include LeavesHolidaysTriggers
  include LeavesHolidaysPermissions

  helper :leave_requests
  include LeaveRequestsHelper

  before_action :set_user
  before_filter :authenticate
  before_action :check_clear_filters
  before_action :check_is_apply_form

  helper :sort
  include SortHelper


  def index
    sort_init 'from_date', 'asc'

    sort_update 'id' => "#{LeaveRequest.table_name}.id",
                'created_at' => "#{LeaveRequest.table_name}.created_at",
                'from_date' => "#{LeaveRequest.table_name}.from_date",
                'to_date' => "#{LeaveRequest.table_name}.to_date"

    @limit = per_page_option

    @users_initial_managed = @user.manages_user_list
    @users_initial_consulted = @user.consulted_user_list
    @users_initial_notified = @user.notified_user_list

    @users_initial_viewable = (@users_initial_managed + @users_initial_consulted + @users_initial_notified).flatten.uniq

    @scope_initial = LeaveRequest.where.not(request_status: 0).where(user_id: @users_initial_viewable.map(&:id))

    scope = @scope_initial

    @show_rejected = params[:show_rejected] || "false"
    @show_contractor = params[:show_contractor] || "false"

    if @show_rejected == "false"
      scope = scope.not_rejected
    end

    if @show_contractor == "false"
      scope = scope.not_from_contractors
    # else
    #   scope = scope.from_contractors
    end

    @scope_initial = scope



    @status_initial = ['1','2','4']
    if params[:status].present?
      @status_selected = params[:status]
      @user.pref[:approval_status_filters] = params[:status]
      @user.preference.save
    else
      @status_selected = @user.pref[:approval_status_filters] if @user.pref[:approval_status_filters].present?
    end

    @status = []
    if @status_selected
      if 'submitted_or_processing'.in?(@status_selected)
        @status << ['1', '4']
      end
      if 'processed'.in?(@status_selected)
        @status << ['2']
      end
      @status = @status.flatten
    end
    
    if @status.any?
      scope = @scope_initial.status(@status)
    end

    @when_initial = ['ongoing', 'coming', 'finished']
    if params[:when].present?
      @when_selected = params[:when]
      @user.pref[:approval_when_filters] = params[:when]
      @user.preference.save
    else
      @when_selected = @user.pref[:approval_when_filters] if @user.pref[:approval_when_filters].present?
    end

    scope = scope.when(@when_selected) if @when_selected

    @reason_initial = @scope_initial.pluck(:issue_id).uniq
    if params[:reason].present?
      @reason_selected = params[:reason]
      @user.pref[:approval_reason_filters] = params[:reason]
      @user.preference.save
    else
      @reason_selected = @user.pref[:approval_reason_filters] if @user.pref[:approval_reason_filters].present?
    end

    scope = scope.reason(@reason_selected) if @reason_selected

    @regions_initial = @scope_initial.group('region').count.to_hash.keys
    if params[:region].present?
      @region_selected = params[:region]
      @user.pref[:approval_region_filters] = params[:region]
      @user.preference.save
    else
      @region_selected = @user.pref[:approval_region_filters] if @user.pref[:approval_region_filters].present?
    end

    scope = scope.where(region: @region_selected) if @region_selected

    if params[:users].present?
      @users_selected = params[:users]
      @user.pref[:approval_users_selected_filters] = params[:users]
      @user.preference.save
    else
      @users_selected = @user.pref[:approval_users_selected_filters] if @user.pref[:approval_users_selected_filters].present?
    end

    scope = scope.where(user: @users_selected) if @users_selected

    @users_managed = @users_initial_managed
    @users_consulted = @users_initial_consulted
    @users_notified = @users_initial_notified

    if @users_selected
      @users_managed   = @users_initial_managed.select{|u| u.id.in?(@users_selected.map(&:to_i))}
      @users_consulted = @users_initial_consulted.select{|u| u.id.in?(@users_selected.map(&:to_i))}
      @users_notified  = @users_initial_notified.select{|u| u.id.in?(@users_selected.map(&:to_i))}
    end


    @leave_count = scope.count
    @leave_pages = Paginator.new @leave_count, @limit, params['page']
    @offset = @leave_pages.offset
    @leave_approvals =  scope.order(sort_clause).limit(@limit).offset(@offset).to_a


  end

  private

  def authenticate
    @auth_status = authenticate_leave_status({action: :index})

    render_403 unless @auth_status
  end

  def set_user
    @user = User.current
  end

  def remove_filters
      @user.pref[:approval_status_filters] = nil
      @user.pref[:approval_when_filters] = nil
      @user.pref[:approval_reason_filters] = nil
      @user.pref[:approval_region_filters] = nil
      @user.pref[:approval_users_selected_filters] = nil
      @user.preference.save
  end

  def check_clear_filters
    if params[:clear_filters].present?
      remove_filters
      params.delete :clear_filters
    end
  end

  def check_is_apply_form
    if params[:apply_form] && params[:apply_form] == "1"
      @is_apply = true
      remove_filters
    end
  end


end