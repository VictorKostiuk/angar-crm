# Settings › Запис › Типові проблеми: the quick picks the Telegram bot offers.
# Deleted outright — bookings keep the text, not a reference.
class BookingProblemsController < ApplicationController
  require_role :admin, :owner

  def create
    problem = BookingProblem.new(problem_params)
    problem.position = BookingProblem.maximum(:position).to_i + 1

    if problem.save
      redirect_to booking_settings_path, notice: "Проблему додано."
    else
      redirect_to booking_settings_path, alert: problem.errors.full_messages.to_sentence
    end
  end

  def update
    problem = BookingProblem.find(params[:id])

    if problem.update(problem_params)
      redirect_to booking_settings_path, notice: "Проблему оновлено."
    else
      redirect_to booking_settings_path, alert: problem.errors.full_messages.to_sentence
    end
  end

  def destroy
    BookingProblem.find(params[:id]).destroy!
    redirect_to booking_settings_path, notice: "Проблему прибрано."
  end

  private
    def problem_params
      params.expect(booking_problem: %i[ name ])
    end
end
