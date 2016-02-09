module LeaveManagementRulesHelper
  include LeavesHolidaysManagements
  
  def actor_type_options_for_select(selected)
    options = LeavesHolidaysManagements.actor_types
    options_for_select(options, selected)
  end

  # Given an actor, "sender" or "receiver", remove selected from available options for opposite actor.
  def actor_collection_for_select_options(project, actor)
    # Return empty list if actor is not a sender nor a receiver
    return [] unless actor.in?(['sender', 'receiver'])
    # Gets the opposite actor of the actor given sender -> receiver, etc.
    actor_opposite = actor == 'sender' ? 'receiver' : 'sender'

    # Gets the type of the sender/receiver, User or Role
    receiver_type = @receiver_type# || LeavesHolidaysManagements.default_actor_type
    sender_type = @sender_type#|| LeavesHolidaysManagements.default_actor_type

    # If actor is the sender, get sender type. otherwise, get receiver type
    actor_type = actor == 'sender' ? sender_type : receiver_type
    actor_opposite_type = actor_opposite == 'sender' ? sender_type : receiver_type
    # Get a list of roles or users with regards to the actor type provided
    list = project.send(actor_type.underscore + "_list")

    # Get the list of ids already selected previously for the other actor
    list_opposite_ids = actor_opposite == 'sender' ? @sender_list_id : @receiver_list_id
    list_opposite_exception_ids = actor_opposite == 'sender' ? @sender_exception_id : @receiver_exception_id
    list_opposite_exception_ids ||= []
    # if the list is not empty
    if list_opposite_ids
      list_opposite = list_opposite_ids.map{|e| e.to_i}
      if actor_type == actor_opposite_type
        list.delete_if {|l| l.id.in?(list_opposite)}
        return list.map{|l| [l.name, l.id]}
      else
        if actor_opposite_type == 'Role' && actor_type == 'User'
          actor_opposite_roles_selected = Role.where(id: list_opposite).to_a
          actor_opposite_associated_user_ids = project.users_for_roles(actor_opposite_roles_selected).map(&:id)
          list.delete_if {|l| l.id.in?(actor_opposite_associated_user_ids - list_opposite_exception_ids.map(&:to_i))}
          return list.map{|l| [l.name, l.id]}
        end
      end
    end

    return list.map{|l| [l.name, l.id]}.sort_by{|t| t[0]}
  end

  def sender_exception_collection_for_select_options(project)
    return [] if @sender_type != "Role" || !@sender_list_id || @sender_list_id.empty?

    receiver_selected = []
    if @receiver_type == "User" && @receiver_list_id
      receiver_selected_ids = @receiver_list_id.map(&:to_i)
      receiver_selected = User.where(id: receiver_selected_ids)
    end
    sender_roles_selected = Role.where(id: @sender_list_id.map{|e| e.to_i}).to_a
    users_associated_with_roles_selected = project.users_for_roles(sender_roles_selected)
    #return [] if users_associated_with_roles_selected.count == 1
    return (users_associated_with_roles_selected + receiver_selected.select{|u| u.in?(users_associated_with_roles_selected)}).uniq.sort_by(&:name).map{|l| [l.name, l.id]}
  end

  def receiver_exception_collection_for_select_options(project)
    return [] if @receiver_type != "Role" || !@receiver_list_id || @receiver_list_id.empty?

    sender_selected = []
    if @sender_type == "User" && @sender_list_id
      sender_selected_ids = @sender_list_id.map(&:to_i)
      sender_selected = User.where(id: sender_selected_ids)
    end
    receiver_roles_selected = Role.where(id: @receiver_list_id.map{|e| e.to_i}).to_a
    users_associated_with_roles_selected = project.users_for_roles(receiver_roles_selected)
    #return [] if users_associated_with_roles_selected.count == 1
    return (users_associated_with_roles_selected + sender_selected.select{|u| u.in?(users_associated_with_roles_selected)}).uniq.sort_by(&:name).map{|l| [l.name, l.id]}
  end

  def backup_receiver_collection_for_select_options(project)
    return [] if @action.to_i != LeaveManagementRule.actions['is_managed_by']

    sender_selected_ids = []
    if @sender_type == "User" && @sender_list_id
      sender_selected_ids = @sender_list_id.map(&:to_i)
    end

    if @sender_type == "Role" && @sender_list_id
      sender_roles_selected = Role.where(id: @sender_list_id.map(&:to_i)).to_a
      users_associated_with_roles_selected = project.users_for_roles(sender_roles_selected)
      if @sender_exception_id
        sender_exception_ids = @sender_exception_id.map(&:to_i)
        users_associated_with_roles_selected.delete_if{|u| u.id.in?(sender_exception_ids)}
      end
      sender_selected_ids = users_associated_with_roles_selected.map(&:id)
    end

    return User.all.active.where.not(id: sender_selected_ids).sort_by(&:name).map{|l| [l.name, l.id]}
  end

  def action_sender_options_for_select(selected)
    options = LeaveManagementRule.actions.to_a.map{|a| [a[0].humanize, a[1]]}.reverse
    options_for_select(options, selected)
  end

  def user_not_contractor_options_for_select(selected)
    options = User.all.active.not_contractor.sort_by(&:name).map{|l| [l.name, l.id]}
    return options_for_select(options, selected)
  end

  def leave_reasons_rules_specifics(selected)
    issues_ids = []
    issues_ids << RedmineLeavesHolidays::Setting.defaults_settings(:available_reasons_contractors)
    issues_ids << RedmineLeavesHolidays::Setting.defaults_settings(:available_reasons_non_contractors)
    issues = Issue.where(id: issues_ids.flatten.uniq)
    options = issues.map {|a| [a.subject, a.id]}
    return options_for_select(options, selected)
  end

  def leave_reasons_select(selected)
    options_for_select([['All leave reasons', 0], ['Specific Leave Reasons:', 1]], selected)
  end

end
