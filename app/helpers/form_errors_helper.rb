# Per-field validation feedback for the modal forms (Bootstrap is-invalid + invalid-feedback).
module FormErrorsHelper
  def field_errors?(record, *attributes)
    return false unless record

    attributes.any? { |attribute| record.errors.include?(attribute) }
  end

  def field_error_class(record, attribute)
    "is-invalid" if field_errors?(record, attribute)
  end

  # Must follow the input as a sibling: Bootstrap shows it via `.is-invalid ~ .invalid-feedback`
  def field_error_feedback(record, attribute)
    return unless field_errors?(record, attribute)

    tag.div(record.errors.full_messages_for(attribute).to_sentence, class: "invalid-feedback")
  end
end
