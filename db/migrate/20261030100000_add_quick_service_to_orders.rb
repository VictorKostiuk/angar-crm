class AddQuickServiceToOrders < ActiveRecord::Migration[8.1]
  def change
    # «Швидкий сервіс» (D71): a job done while the client waits — a mechanic,
    # the services and the materials, entered in one go and closed at once.
    # It is still an order, so payroll, stock and Фінанси count it the same way.
    add_column :orders, :quick, :boolean, null: false, default: false

    # Nobody is asked for a name or a bike for a five-minute job. A regular
    # order still needs both; the model says so.
    change_column_null :orders, :client_id, true
    change_column_null :orders, :bike_id, true
  end
end
