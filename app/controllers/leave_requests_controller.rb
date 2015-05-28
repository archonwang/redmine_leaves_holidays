class LeaveRequestsController < ApplicationController
  unloadable
  include LeavesHolidaysLogic
  include LeavesHolidaysDates
  before_action :set_leave_request, only: [:show, :edit, :update, :destroy, :submit, :unsubmit]
  before_action :set_status, only: [:show, :destroy]
  before_filter :authenticate, only: [:show, :edit, :update, :destroy]
  # before_action :view_request, only: [:show]
  # before_action :manage_request, only: [:edit, :update, :destroy]
  before_action :set_issue_trackers
  before_action :set_checkboxes, only: [:edit, :update]

  helper :sort
  include SortHelper

  def index
    sort_init 'from_date', 'asc'

    sort_update 'id' => "#{LeaveRequest.table_name}.id",
                'from_date' => "#{LeaveRequest.table_name}.from_date",
                'to_date' => "#{LeaveRequest.table_name}.to_date"



    @leave_requests = {}
    @leave_requests['requests'] = LeaveRequest.for_user(User.current.id).reorder(sort_clause)#.pending
    # @leave_requests = LeaveRequest.all
  	@leave_requests['approvals'] = LeaveRequest.processable_by(User.current.id)#.reorder(sort_clause)#.pending

    # @leave_requests['requests'] =  @leave_requests['requests'].reorder(sort_clause)
    # @notifiers = LeavesHolidaysLogic.users_to_notify_of_request(User.current)
    # @approvers = LeavesHolidaysLogic.can_approve_request(User.current)
    # job = Rufus::Scheduler.singleton.every '30s' do
    #     Rails.logger.info "SCHEDULER: time flies, it's now #{Time.now}"
    # end
    # p job.running?   # true
    # job.kill if job.running?
    # p job.running?   # false
    @d_start = LeavesHolidaysLogic.user_params(User.current, :contract_start_date).to_date
    @d_end = @d_start + 1.year - 1.day
    @dates = LeavesHolidaysDates.total_leave_days_remaining(User.current, @d_start, @d_end)

  end

  def new
  	@leave = LeaveRequest.new
  end

  def create
  	@leave = LeaveRequest.new(leave_request_params)
  	if @leave.save
      flash[:notice] = "Your leave request was successfully created. Do not forget to submit it for approval by hitting the \"Submit\" Button"
  		redirect_to @leave
  	else
  		render new_leave_request_path
  	end
  end

  def submit
    unless @leave.request_status == "created" && User.current == @leave.user
      render_403
      return
    else
      @leave.update_attribute(:request_status, "submitted")
      flash[:notice] = "Your leave request has been submitted for approval"
      redirect_to @leave
    end
  end

  def unsubmit
    unless @leave.request_status == "submitted" && User.current == @leave.user
      render_403
      return
    else
      @leave.update_attribute(:request_status, "created")
      flash[:notice] = "Your leave request has been unsubmitted."
      redirect_to @leave
    end
  end

  def show
  end

  def edit
    # render_403 unless @leave.request_status == "created" && User.current == @leave.user
  end

  def update
    if @leave.update(leave_request_params)
  		redirect_to @leave #:action => 'index'
  	else
  		render :edit
  	end
  end

  def destroy
    leave_relations = LeaveRequest.where(id: @leave.id)

    if leave_relations.processed.exists?
      if leave_relations.accepted.ongoing_or_finished.exists?
        flash[:error] = "You cannot cancel this leave as it has already been approved and is in the past"
        redirect_to leave_requests_path
        return
      end
      @status.update_attribute(:acceptance_status, "cancelled")
    end

    @leave.update_attribute(:request_status, "cancelled")
    redirect_to leave_requests_path
  end

  private

  def set_leave_request
    begin
  	  @leave = LeaveRequest.find(params[:id])
  	rescue ActiveRecord::RecordNotFound
  		render_404
  	end
  end

  def set_status
    if @leave.request_status == "processed"
      @status = LeaveStatus.for_request(@leave.id).first if @status == nil
    end
  end

  def set_checkboxes
  	@leave.leave_time_am = @leave.has_am?
  	@leave.leave_time_pm = @leave.has_pm?
  end

  def set_issue_trackers
  	@issues_trackers = LeavesHolidaysLogic.issues_list if @issues_trackers == nil
  end

  def leave_request_params
  	params.require(:leave_request).permit(:from_date, :to_date, :user_id, :issue_id, :leave_time_am, :leave_time_pm, :comments)
  end

  def authenticate
    render_403 unless LeavesHolidaysLogic.has_right(User.current, @leave.user, @leave, params[:action].to_sym)
  end

end
