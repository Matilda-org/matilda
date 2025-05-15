# This concern is used on models with alghoritmic_order column.
# These models have a column called alghoritmic_order that is used to order the records based on an alghoritm
# that calculate the importance of the record based on its position on procedures.
#
# NOTE: Model should have a procedures_items association.

module AlghoritmicOrderable
  extend ActiveSupport::Concern

  def alghoritmic_order_recalculate
    return false unless defined?(procedures_items)

    data = []
    procedures_items.includes(:procedures_status).each do |item|
      data << {
        item_id: item.id,
        order: item.order || 1,
        status_order: item.procedures_status&.order || 1
      }
    end

    data = data.map { |d| d[:order] * d[:status_order] }.sort

    calculated_alghoritmic_order = (data.sum / data.size.to_f).round
    update_columns(alghoritmic_order: calculated_alghoritmic_order) if alghoritmic_order != calculated_alghoritmic_order

    true
  end
end
