class AddWorksAsMechanicToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :works_as_mechanic, :boolean, null: false, default: false
  end
end
