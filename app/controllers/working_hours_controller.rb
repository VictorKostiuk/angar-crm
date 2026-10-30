# The whole week is saved at once — seven rows, one form, one Save — because
# that is how a shop thinks about its hours.
class WorkingHoursController < ApplicationController
  require_role :admin, :owner

  def update
    rows = WorkingHour.week
    params_by_day = params.expect(working_hours: [ [ :weekday, :closed, :opens_at, :closes_at, :slot_minutes, :capacity ] ])
    by_weekday = params_by_day.to_h.values.index_by { |attrs| attrs[:weekday].to_i }

    rows.each { |row| row.assign_attributes(by_weekday.fetch(row.weekday, {}).except(:weekday)) }
    invalid = rows.reject(&:valid?)

    if invalid.empty?
      WorkingHour.transaction { rows.each(&:save!) }
      redirect_to booking_settings_path, notice: "Розклад збережено."
    else
      messages = invalid.map { |row| "#{row.day_name}: #{row.errors.full_messages.to_sentence}" }
      redirect_to booking_settings_path, alert: messages.join("; ")
    end
  end
end
