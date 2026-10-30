# A client's ID photos (D67), kept with the person so a second hire does not
# need the passport shot again. Same rules as RentalDocumentsController: every
# role adds — whoever hands the bike over holds the phone — and only admin or
# owner deletes someone's ID.
class ClientDocumentsController < ApplicationController
  require_role :admin, :owner, only: :destroy

  before_action :set_client

  # The «Видати в прокат» form loads this into its frame when a client is
  # picked, to say what is already on file.
  def index
    @documents = @client.all_documents
    render layout: false
  end

  def create
    files = Array(params[:documents]).compact_blank

    if files.any? { |file| !file.content_type.to_s.start_with?("image/") }
      redirect_back_or_to @client, alert: "Документ має бути зображенням."
    elsif files.any? && !@client.documents.attach(files)
      redirect_back_or_to @client, alert: "Документи не збережено: #{@client.errors.full_messages.to_sentence}."
    else
      redirect_back_or_to @client, notice: "Документи додано."
    end
  end

  def destroy
    @client.documents.find(params[:id]).purge
    redirect_back_or_to @client, notice: "Документ видалено."
  end

  private
    def set_client
      @client = Client.find(params[:client_id])
    end
end
