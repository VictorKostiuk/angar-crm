class MaintenanceTypesController < ApplicationController
  require_role :admin, :owner

  def create
    type = MaintenanceType.new(type_params)
    type.position = MaintenanceType.maximum(:position).to_i + 1

    if type.save
      redirect_to booking_settings_path, notice: "Тип ТО додано."
    else
      redirect_to booking_settings_path, alert: type.errors.full_messages.to_sentence
    end
  end

  def update
    type = MaintenanceType.find(params[:id])

    if type.update(type_params)
      redirect_to booking_settings_path, notice: "Тип ТО оновлено."
    else
      redirect_to booking_settings_path, alert: type.errors.full_messages.to_sentence
    end
  end

  # Archived, not deleted: past bookings still name the type they were for.
  def destroy
    MaintenanceType.find(params[:id]).update!(active: false)
    redirect_to booking_settings_path, notice: "Тип ТО прибрано із запису."
  end

  private
    def type_params
      params.expect(maintenance_type: %i[ name duration_minutes description active ])
    end
end
