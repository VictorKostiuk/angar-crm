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
      redirect_to expenses_path, notice: "Витрату додано."
    else
      load_index_data
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @expense = Expense.find(params[:id])

    if @expense.update(expense_params)
      redirect_to expenses_path, notice: "Витрату оновлено."
    else
      load_index_data
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    Expense.find(params[:id]).destroy
    redirect_to expenses_path, notice: "Витрату видалено."
  end

  private
    def expense_params
      params.expect(expense: %i[ category amount description date ])
    end

    def load_index_data
      @expenses = Expense.ordered.includes(:stock_movement)
    end
end
