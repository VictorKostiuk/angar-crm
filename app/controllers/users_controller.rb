class UsersController < ApplicationController
  require_role :owner

  def index
    load_index_data
    @user = params[:edit].present? ? User.find(params[:edit]) : User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to users_path, notice: "Користувача додано."
    else
      load_index_data
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @user = User.find(params[:id])

    if @user.update(user_params.compact_blank)
      redirect_to users_path, notice: "Користувача оновлено."
    else
      load_index_data
      render :index, status: :unprocessable_entity
    end
  end

  private
    def user_params
      params.expect(user: %i[ name email_address phone role payroll_percent active password ])
    end

    def load_index_data
      @users = User.order(:name)
    end
end
