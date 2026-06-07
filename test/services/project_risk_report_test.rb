require "test_helper"

class ProjectRiskReportTest < ActiveSupport::TestCase
  test "returns project risks ordered by score" do
    low_risk_project = Project.create!(code: "LOW", name: "Low Risk", year: 2026)
    high_risk_project = Project.create!(code: "HIGH", name: "High Risk", year: 2026, budget_management: true, budget_time: 100)

    low_risk_project.tasks.create!(title: "Unassigned", deadline: Date.tomorrow)
    high_risk_project.tasks.create!(title: "Expired", deadline: Date.yesterday, time_spent: 120)

    items = ProjectRiskReport.new(Project.where(id: [ low_risk_project.id, high_risk_project.id ])).items

    assert_equal high_risk_project, items.first[:project]
    assert_includes items.first[:signals].map { |signal| signal[:label] }, "1 task scaduti"
    assert_includes items.first[:signals].map { |signal| signal[:label] }, "1 task senza owner"
    assert_includes items.first[:signals].map { |signal| signal[:label] }, "Budget tempo al 120.0%"
  end

  test "ignores projects without risk signals" do
    project = Project.create!(code: "SAFE", name: "Safe Project", year: 2026)
    project.tasks.create!(title: "Assigned", deadline: Date.tomorrow, user: users(:one))

    items = ProjectRiskReport.new(Project.where(id: project.id)).items

    assert_empty items
  end
end
