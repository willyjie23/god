# frozen_string_literal: true

# ActiveAdmin 3.x 的日期區間篩選器把結束日送成 `<欄位>_lteq=2026-11-08`，
# 對 datetime 欄位會變成 `<= 2026-11-08 00:00:00`，結束日當天的資料全被排除。
# 這裡加一個「小於隔天 00:00（Time.zone）」的 predicate，並讓 datetime 欄位的結束日改用它。
Ransack.configure do |config|
  config.add_predicate "lteq_end_of_day",
                       arel_predicate: "lt",
                       formatter: ->(v) { v.to_date.next_day.in_time_zone },
                       type: :date
end

module DateRangeInputInclusiveEndDay
  def lt_input_name
    datetime_column? ? "#{method}_lteq_end_of_day" : super
  end

  private

  def datetime_column?
    klass = @object.respond_to?(:klass) ? @object.klass : nil
    klass&.columns_hash&.dig(method.to_s)&.type == :datetime
  end
end

Rails.application.config.to_prepare do
  input = ActiveAdmin::Inputs::Filters::DateRangeInput
  input.prepend(DateRangeInputInclusiveEndDay) unless input <= DateRangeInputInclusiveEndDay
end
