module ApplicationHelper
  # 1920.0 -> "1 920 грн"
  def money(amount)
    return "—" if amount.nil?

    grouped = amount.round.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1 ').reverse
    "#{grouped} грн"
  end

  # order.number == 24 -> "#024"
  def order_number(order)
    "##{format('%03d', order.number)}"
  end
end
