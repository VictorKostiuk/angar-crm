class CategoriesController < ApplicationController
  # D38: reachable from the Послуги/Запчастини pages, which every role can now
  # use — a visible "+ категорія" button that silently redirects is worse than
  # no button.
  layout "modal", only: %i[ new create ]

  def new
    @category = Category.new(kind: params[:kind])
  end

  def create
    @category = Category.new(category_params)

    if @category.save
      redirect_to (@category.service? ? services_path : parts_path), notice: "Категорію додано."
    else
      render "shared/modal_form_error", locals: { form_template: "categories/new" }, status: :unprocessable_entity
    end
  end

  private
    def category_params
      params.expect(category: %i[ name kind ])
    end
end
