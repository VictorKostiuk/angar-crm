# Settings › Запис: the regular week, the kinds of ТО, the dates that differ
# and the problems the Telegram bot offers as quick picks.
# Each section posts to its own small controller; they all land back here.
class BookingSettingsController < ApplicationController
  require_role :admin, :owner

  def show
    @week = WorkingHour.week
    @types = MaintenanceType.ordered
    @type = MaintenanceType.new(duration_minutes: 60)
    @exceptions = ScheduleException.upcoming
    @exception = ScheduleException.new(date: Date.current + 1)
    @problems = BookingProblem.ordered
    @problem = BookingProblem.new
  end
end
