class LeaveManagementRulesController < ApplicationController
  unloadable
  include LeavesHolidaysManagements
  before_action :find_project
  before_action :authorize

  helper :leave_management_rules
  helper :leave_requests
  include LeaveManagementRulesHelper

  def edit
    unless params[:edit] && params[:edit] == "true"
      session[:management_rule_ids] = nil
    end

    unless params[:management_rule_ids]
      @sender_type = params[:sender_type] || LeavesHolidaysManagements.default_actor_type
      @sender_list_id ||= params[:sender_list_id]
      @sender_exception_id ||= params[:sender_exception_id]

      @action = params[:action_rule] || LeaveManagementRule.actions['is_managed_by'] 
      
      @receiver_type = params[:receiver_type] || LeavesHolidaysManagements.default_actor_type
      @receiver_list_id ||= params[:receiver_list_id]
      @receiver_exception_id ||= params[:receiver_exception_id]
      @backup_receiver_id ||= params[:backup_receiver_id]
      
      @reason_selected = 0
      @reason_selected = params[:reasons_selected] if params[:reasons_selected]

      @reasons_concerned_ids ||= params[:reasons_concerned_id]

    else
      management_rules = LeaveManagementRule.where(id: params[:management_rule_ids], project: @project)
      management_rule_ids = management_rules.pluck(:id)
      sender_exceptions = LeaveExceptionRule.where(leave_management_rule_id: management_rule_ids, actor_concerned: LeaveExceptionRule.actors_concerned[:sender])
      receiver_exceptions = LeaveExceptionRule.where(leave_management_rule_id: management_rule_ids, actor_concerned: LeaveExceptionRule.actors_concerned[:receiver])
      backup_receiver = LeaveExceptionRule.where(leave_management_rule_id: management_rule_ids, actor_concerned: LeaveExceptionRule.actors_concerned[:backup_receiver])
      reasons_concerned = LeaveReasonRule.where(leave_management_rule_id: management_rule_ids)

      @sender_type = management_rules.first.sender_type_form
      @sender_list_id ||= management_rules.pluck(:sender_id)
      @sender_exception_id ||= sender_exceptions.pluck(:user_id)

      @action = LeaveManagementRule.actions[management_rules.first.action]

      @receiver_type = management_rules.first.receiver_type_form
      @receiver_list_id ||= management_rules.pluck(:receiver_id)
      @receiver_exception_id ||= receiver_exceptions.pluck(:user_id)
      @backup_receiver_id ||= backup_receiver.pluck(:user_id)
      @reasons_concerned_ids ||= reasons_concerned.pluck(:issue_id)
      @reason_selected = 0
      @reason_selected = 1 if @reasons_concerned_ids.any?
      session[:management_rule_ids] = management_rule_ids
    end
  end

  def update
    if params[:delete] && params[:delete] == "true" && params[:management_rule_ids] && !params[:management_rule_ids].empty?
        LeaveManagementRule.destroy_all(id: params[:management_rule_ids].map(&:to_i), project: @project)
    else
      if session[:management_rule_ids] && !session[:management_rule_ids].empty?
        LeaveManagementRule.destroy_all(id: session[:management_rule_ids].map(&:to_i), project: @project)
      end
      if params[:sender_list_id] && params[:receiver_list_id]
        @leave_management_rule_errors = []
        params[:sender_list_id].each do |sender_id|
          params[:receiver_list_id].each do |receiver_id|
            @leave_management_rule = LeaveManagementRule.new(project: @project, sender: params[:sender_type].constantize.find(sender_id.to_i), receiver: params[:receiver_type].constantize.find(receiver_id.to_i), action: LeaveManagementRule.actions.select{|k,v| v == params[:action_rule].to_i}.keys.first)
            #if @leave_management_rule.save

              if params[:sender_exception_id]
                params[:sender_exception_id].each do |sender_excpt|
                  LeaveExceptionRule.create(leave_management_rule: @leave_management_rule, actor_concerned: :sender, user: User.find(sender_excpt.to_i))
                end
              end
              if params[:receiver_exception_id]
                params[:receiver_exception_id].each do |receiver_excpt|
                  LeaveExceptionRule.create(leave_management_rule: @leave_management_rule, actor_concerned: :receiver, user: User.find(receiver_excpt.to_i))
                end
              end
              if params[:backup_receiver_id]
                params[:backup_receiver_id].each do |backup_receiver|
                  LeaveExceptionRule.create(leave_management_rule: @leave_management_rule, actor_concerned: :backup_receiver, user: User.find(backup_receiver.to_i))
                end
              end

              @reason_selected = '0'
              @reason_selected = params[:reasons_selected] if params[:reasons_selected]

              if params[:reasons_concerned_id] && @reason_selected == '1'
                params[:reasons_concerned_id].each do |reason|
                  LeaveReasonRule.create(leave_management_rule: @leave_management_rule, issue: Issue.find(reason.to_i))
                end
              end

            #else
            if @leave_management_rule.save
            else
              @leave_management_rule_errors << @leave_management_rule
              return
            end
            #end

          end
        end
      end
      
    end
    session[:management_rule_ids] = nil

  end

  def show_metrics
    render :layout => false
  end

  def index
    respond_to do |format|
      format.html { head 406 }
    end
  end

  def enable
    LeavesHolidaysManagementsModules.enable_leave_management_rules_project(@project)
    redirect_to settings_project_path(@project, 'leave_management')
  end

  def disable
    LeavesHolidaysManagementsModules.disable_leave_management_rules_project(@project)
    redirect_to settings_project_path(@project, 'leave_management')
  end

  private

  def find_project
    @project ||= Project.find(params[:project_id])
  end

  def redirect_to_settings_in_projects
    redirect_to settings_project_path(@project, :tab => 'leave_management')
  end

end