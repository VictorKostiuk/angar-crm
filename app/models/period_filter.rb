# Shared period parsing for the mechanics list/card and reports screens
# (mockups 15-17 all show the same "День / Тиждень / Місяць / діапазон"
# switcher). Boundaries use Time.zone.today.all_* rather than hand-built
# Date ranges so a month report doesn't leak hours across a UTC/Kyiv offset.
class PeriodFilter
  PERIODS = %w[ day week month range ].freeze

  attr_reader :period, :range

  def initialize(period: nil, from: nil, to: nil)
    @period = PERIODS.include?(period) ? period : "month"
    @range = build_range(from, to)
  end

  def from = range.begin
  def to = range.end

  private
    def build_range(from, to)
      case period
      when "day" then Time.zone.today.all_day
      when "week" then Time.zone.today.all_week
      when "range" then custom_range(from, to)
      else Time.zone.today.all_month
      end
    end

    def custom_range(from, to)
      parsed_from = parse_date(from) || Time.zone.today
      parsed_to = parse_date(to) || Time.zone.today
      parsed_from, parsed_to = parsed_to, parsed_from if parsed_from > parsed_to

      parsed_from.all_day.begin..parsed_to.all_day.end
    end

    def parse_date(value)
      Date.parse(value) if value.present?
    rescue ArgumentError
      nil
    end
end
