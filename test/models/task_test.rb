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
    assert_includes today_tasks.map(&:title), "Task one"
  end

  test "scope expired" do
    expired_tasks = Task.expired
    assert_includes expired_tasks.map(&:title), "Task two"
  end

  test "scope not_expired" do
    not_expired_tasks = Task.not_expired
    assert_includes not_expired_tasks.map(&:title), "Task one"
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

  test "add_manual_track! crea un track chiuso e incrementa time_spent" do
    task = tasks(:one)
    before = task.time_spent

    track = task.add_manual_track!(user: users(:one), date: Date.today - 2, duration: 7200)

    assert_not_nil track.end_at
    assert_equal 7200, track.time_spent
    assert_equal 7200, (track.end_at - track.start_at).to_i
    assert_equal before + 7200, task.reload.time_spent
  end

  test "add_manual_track! rifiuta durate non positive" do
    task = tasks(:one)
    assert_raises(ArgumentError) { task.add_manual_track!(user: users(:one), date: Date.today, duration: 0) }
  end
end
