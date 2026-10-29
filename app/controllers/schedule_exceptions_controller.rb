class ScheduleExceptionsController < ApplicationController
  require_role :admin, :owner

  def create
    exception = ScheduleException.new(exception_params)

    if exception.save
      redirect_to booking_settings_path, notice: "Особливий день додано."
    else
      redirect_to booking_settings_path, alert: exception.errors.full_messages.to_sentence
    end
  end

  def destroy
    ScheduleException.find(params[:id]).destroy
    redirect_to booking_settings_path, notice: "Особливий день прибрано."
  end

  private
    def exception_params
      params.expect(schedule_exception: %i[ date closed opens_at closes_at capacity note ])
    end
end
