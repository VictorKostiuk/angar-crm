class AnnouncementsController < ApplicationController
  require_role :owner

  def edit
    @announcement = Announcement.current
  end

  # Announcement.current returns an unsaved record until the owner saves once,
  # so this both creates and updates — there is only ever the one row.
  def update
    @announcement = Announcement.current

    if @announcement.update(announcement_params)
      redirect_to edit_announcement_path, notice: "Оголошення збережено."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def announcement_params
      params.expect(announcement: %i[ text active ])
    end
end
