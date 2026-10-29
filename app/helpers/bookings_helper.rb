module BookingsHelper
  # The day in a list that spans several: "Сьогодні", "Завтра", "Вт. 03.11".
  def booking_day_label(date)
    case date
    when Date.current then "Сьогодні"
    when Date.tomorrow then "Завтра"
    else l(date, format: "%a %d.%m").upcase_first
    end
  end
end
