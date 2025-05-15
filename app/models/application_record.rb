class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  protected

  def capitalize_first_char(string)
    return unless string

    string.slice(0, 1).capitalize + string.slice(1..-1)
  end
end
