# Row/feature level authorization shared by the assistant tools, so reads and
# writes apply the same rules the controllers apply. Expects @user.
module VectorsearchTools::Access
  private

  # Mirrors ApplicationController#query_projects_for_policy: users flagged
  # only_data_projects_as_member can only see projects they belong to.
  def restricted_to_member_projects?
    @user&.policy?("only_data_projects_as_member")
  end

  def accessible_projects
    restricted_to_member_projects? ? Project.where(id: @user.projects_as_member_ids) : Project.all
  end

  def accessible_tasks
    restricted_to_member_projects? ? Task.where(project_id: @user.projects_as_member_ids) : Task.all
  end

  # Mirrors ApplicationController#query_procedures_for_policy: boards without a
  # project stay visible to everyone.
  def accessible_procedures
    return Procedure.all unless restricted_to_member_projects?

    Procedure.where(project_id: @user.projects_as_member_ids).or(Procedure.where(project_id: nil))
  end

  # same single policy that gates the whole CRM section
  def can_access_crm?
    @user&.policy?("crm")
  end
end
