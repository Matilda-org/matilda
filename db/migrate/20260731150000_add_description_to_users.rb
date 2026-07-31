# frozen_string_literal: true

# Free-text profile description, editable from the user form and exposed on the API.
class AddDescriptionToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :description, :text
  end
end
