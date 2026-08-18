class UsersController < ApplicationController
  require_role :owner

  def index
    load_index_data
    @user = params[:edit].present? ? User.find(params[:edit]) : User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      respond_to do |format|
        format.turbo_stream { load_index_data_and_reset_form; render :refresh }
        format.html { redirect_to users_path, notice: "Користувача додано." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { load_index_data; render :index, status: :unprocessable_entity }
      end
    end
  end

  def update
    @user = User.find(params[:id])

    if @user.update(user_params.compact_blank)
      respond_to do |format|
        format.turbo_stream { load_index_data_and_reset_form; render :refresh }
        format.html { redirect_to users_path, notice: "Користувача оновлено." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { load_index_data; render :index, status: :unprocessable_entity }
      end
    end
  end

  private
    def user_params
      params.expect(user: %i[ name email_address phone role payroll_percent active password ])
    end

    def load_index_data
      @users = User.order(:name)
    end

    def load_index_data_and_reset_form
      load_index_data
      @user = User.new
    end
end
