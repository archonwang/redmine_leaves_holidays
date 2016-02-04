class LeaveStatusesController < ApplicationController
  unloadable
  include LeavesHolidaysLogic
  include LeavesHolidaysPermissions
  
  before_action :set_user, :set_leave_request, :set_leave_status, :set_leave_vote
  
  before_action :authenticate

  def new
    if @status != nil
      redirect_to edit_leave_request_leave_status_path
    else
      @status = LeaveStatus.new
    end
  end

  def create
    @leave = LeaveRequest.find(params[:leave_request_id])

    @status = LeaveStatus.new(leave_status_params) if @status == nil
    @status.leave_request = @leave

    if @status.save
       @leave.update_attribute(:request_status, "processed")

       redirect_to leave_approvals_path
    else
       redirect_to new_leave_request_leave_status_path
    end
  end

  def edit
  end

  def update
    if @status.update(leave_status_params)
       redirect_to leave_approvals_path
    else
       redirect_to @status
    end
  end

  def destroy
      render_403
  end

  private

  def set_user
    @user = User.current
  end

  def leave_status_params
    params.require(:leave_status).permit(:leave_request_id, :processed_date, :user_id, :comments, :acceptance_status)
  end

  def set_leave_status
    @status ||= LeaveStatus.where(leave_request_id: @leave.id).first
  end

  def set_leave_request
    begin
      @leave ||= LeaveRequest.find(params[:leave_request_id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end
  end

  def set_leave_vote
      @votes ||= LeaveVote.for_request(@leave.id)
  end

  def authenticate
    
    @auth_status = authenticate_leave_status(params)

    render_403 unless @auth_status

  end

end
