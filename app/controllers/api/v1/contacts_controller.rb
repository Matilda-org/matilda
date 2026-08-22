# frozen_string_literal: true

# Contacts API: CRM contacts read access and creation (e.g. import from
# external campaign tools).
class Api::V1::ContactsController < Api::V1::BaseController
  # POST /api/v1/contacts
  def create
    return unless require_policy!("crm")

    contact = Contact.new(params.permit(:name, :vat_number, :email, :phone, :website, :address, :description))
    return render_record_errors(contact) unless contact.save

    render json: contact.as_json, status: :created
  end

  # GET /api/v1/contacts
  def index
    return unless require_policy!("crm")

    contacts = Contact.order(name: :asc)
    contacts = contacts.not_archived unless params[:archived].present?
    contacts = contacts.archived if params[:archived].present?
    contacts = contacts.search(params[:search]) if params[:search].present?
    render_paginated(contacts)
  end

  # GET /api/v1/contacts/:id
  def show
    return unless require_policy!("crm")

    contact = Contact.find(params[:id])
    render json: contact.as_json(include: [ :communications, :projects ])
  end
end
