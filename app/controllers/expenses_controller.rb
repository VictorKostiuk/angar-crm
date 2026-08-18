class ExpensesController < ApplicationController
  require_role :admin, :owner

  def index
    load_index_data
    @expense = params[:edit].present? ? Expense.find(params[:edit]) : Expense.new(date: Date.current)
  end

  def create
    @expense = Expense.new(expense_params)
    @expense.user = Current.user

    if @expense.save
      respond_to do |format|
        format.turbo_stream { load_index_data_and_reset_form; render :refresh }
        format.html { redirect_to expenses_path, notice: "Витрату додано." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { load_index_data; render :index, status: :unprocessable_entity }
      end
    end
  end

  def update
    @expense = Expense.find(params[:id])

    if @expense.update(expense_params)
      respond_to do |format|
        format.turbo_stream { load_index_data_and_reset_form; render :refresh }
        format.html { redirect_to expenses_path, notice: "Витрату оновлено." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :form_error, status: :unprocessable_entity }
        format.html { load_index_data; render :index, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    Expense.find(params[:id]).destroy

    respond_to do |format|
      format.turbo_stream do
        load_index_data
        render turbo_stream: turbo_stream.update("expenses_rows", partial: "rows", locals: { expenses: @expenses })
      end
      format.html { redirect_to expenses_path, notice: "Витрату видалено." }
    end
  end

  private
    def expense_params
      params.expect(expense: %i[ category amount description date ])
    end

    def load_index_data
      @expenses = Expense.ordered.includes(:stock_movement)
    end

    def load_index_data_and_reset_form
      load_index_data
      @expense = Expense.new(date: Date.current)
    end
end
