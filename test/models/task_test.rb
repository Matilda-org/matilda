require "test_helper"

class TaskTest < ActiveSupport::TestCase
  test "validità di una task con titolo" do
    task = Task.new(title: "Titolo valido")
    assert task.valid?
  end

  test "non valida senza titolo" do
    task = Task.new(title: nil)
    assert_not task.valid?
  assert_includes task.errors[:title], "non può essere lasciato in bianco"
  end

  test "lunghezza massima del titolo" do
    task = Task.new(title: "a" * 201)
    assert_not task.valid?
  assert_includes task.errors[:title], "è troppo lungo (il massimo è 200 caratteri)"
  end

  test "scope today" do
    today_tasks = Task.today
    assert_includes today_tasks.map(&:title), "Task uno"
  end

  test "scope expired" do
    expired_tasks = Task.expired
    assert_includes expired_tasks.map(&:title), "Task due"
  end

  test "scope not_expired" do
    not_expired_tasks = Task.not_expired
    assert_includes not_expired_tasks.map(&:title), "Task uno"
  end

  test "expired? method" do
    task = tasks(:two)
    assert task.expired?
    task = tasks(:one)
    assert_not task.expired?
  end

  test "today? method" do
    task = tasks(:one)
    assert task.today?
    task = tasks(:two)
    assert_not task.today?
  end

  test "subtitle restituisce deadline_in_words o completed_at_in_words" do
    task = tasks(:one)
    assert_equal task.deadline_in_words, task.subtitle
    task = tasks(:two)
    assert_equal task.completed_at_in_words, task.subtitle
  end

  test "time_alert true se time_spent > time_estimate" do
    task = tasks(:two)
    assert task.time_alert
    task = tasks(:one)
    assert_not task.time_alert
  end

  test "color_type restituisce il tipo corretto" do
    task = tasks(:one)
  assert_equal "warning", task.color_type
    task = tasks(:two)
  assert_equal "secondary", task.color_type
  end
end
