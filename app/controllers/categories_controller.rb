class CategoriesController < ApplicationController
  require_role :admin, :owner
  layout "modal", only: %i[ new create ]

  def new
    @category = Category.new(kind: params[:kind])
  end

  def create
    @category = Category.new(category_params)

    if @category.save
      redirect_to (@category.service? ? services_path : parts_path), notice: "Категорію додано."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def category_params
      params.expect(category: %i[ name kind ])
    end
end
