# The search box in the header (D69). It used to send the query to the orders
# list, which hides closed and cancelled orders by default — so a bike whose
# visits were all finished could not be found from the header at all. Now it
# looks for the bike itself, plus clients and order numbers.
#
# Typing fills a dropdown (the "global_search_results" frame, a few of each);
# Enter opens this as a page with everything that matched.
class SearchController < ApplicationController
  DROPDOWN_LIMIT = 6
  PAGE_LIMIT = 50

  def index
    @query = params[:q].to_s.strip
    limit = turbo_frame_request? ? DROPDOWN_LIMIT : PAGE_LIMIT

    if @query.empty?
      @bikes = @clients = @orders = []
    else
      @bikes = Bike.matching(@query).includes(:client, photos_attachments: :blob, orders: { photos_attachments: :blob })
                   .order(active: :desc, name: :asc).limit(limit).to_a
      @in_shop_ids = Bike.in_shop_ids(@bikes)
      @clients = Client.search(@query).order(:name).limit(limit).to_a
      @orders = order_number_matches
    end

    render layout: false if turbo_frame_request?
  end

  private
    # "24", "#024" — an order number typed on its own.
    def order_number_matches
      number = @query.delete_prefix("#")
      return [] unless number.match?(/\A\d{1,7}\z/)

      Order.where(number: number.to_i).includes(:client, :bike).to_a
    end
end
