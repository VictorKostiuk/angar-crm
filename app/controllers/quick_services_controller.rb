# «Швидкий сервіс» (D71): a short job entered in one form from Майстерня —
# mechanic, services, materials — and closed on the spot, so it counts toward
# the mechanic's payroll without walking an order through intake and close.
# Every role, like a counter sale: the mechanic who did the job often enters it.
class QuickServicesController < ApplicationController
  layout "modal", only: %i[ new create ]

  def new
    mechanic = Current.user if Current.user.assignable_as_mechanic?
    @order = Order.new(quick: true, mechanic: mechanic)
    load_form_data
  end

  def create
    @order = Orders::QuickCreate.call(attributes: quick_service_params, accepted_by: Current.user)

    if @order.persisted?
      redirect_to root_path, notice: "Швидкий сервіс #{helpers.order_number(@order)} записано — #{helpers.money(@order.total)}."
    else
      load_form_data
      render "shared/modal_form_error", locals: { form_template: "quick_services/new" }, status: :unprocessable_entity
    end
  end

  private
    def load_form_data
      @order.order_works.build if @order.order_works.empty?
      @order.order_parts.build if @order.order_parts.empty?
      @mechanics = User.assignable_as_mechanic.active.order(:name)
      @services = Service.active.ordered
      @parts = Part.active.ordered
    end

    def quick_service_params
      params.expect(order: [ :mechanic_id, :comment,
                             { order_works_attributes: [ [ :service_id, :name, :quantity, :price ] ],
                               order_parts_attributes: [ [ :part_id, :name, :quantity, :price ] ] } ])
    end
end
