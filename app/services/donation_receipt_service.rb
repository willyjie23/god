# frozen_string_literal: true

class DonationReceiptService
  ORGANIZATION_NAME = "佳里廣澤信仰宗教協會"
  ORGANIZATION_ADDRESS = "台南市佳里區"
  STAMP_IMAGE = "public/images/大章.jpg"

  # 配色（與 HTML 預覽一致）
  COLORS = {
    gold: "C9A227",
    dark_red: "8B0000",
    dark_gray: "333333",
    medium_gray: "666666",
    light_gray: "EEEEEE",
    cream: "FFFBEB",
    white: "FFFFFF"
  }.freeze

  def initialize(donation)
    @donation = donation
  end

  def generate_pdf
    Prawn::Document.new(page_size: "A4", margin: 50) do |pdf|
      setup_font(pdf)
      draw_header(pdf)
      draw_details_section(pdf)
      draw_line_items(pdf)
      draw_stamp(pdf)
      draw_footer(pdf)
    end
  end

  def render
    generate_pdf.render
  end

  def filename
    "捐款收據_#{@donation.receipt_number}.pdf"
  end

  private

  def setup_font(pdf)
    font_path = find_chinese_font
    if font_path
      pdf.font_families.update(
        "Chinese" => {
          normal: font_path,
          bold: font_path
        }
      )
      pdf.font "Chinese"
    end
  end

  def find_chinese_font
    paths = [
      Rails.root.join("app/assets/fonts/NotoSansTC-Regular.ttf"),
      "/System/Library/Fonts/STHeiti Light.ttc",
      "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc"
    ]
    paths.find { |p| File.exist?(p) }&.to_s
  end

  def draw_header(pdf)
    # 標題和協會資訊並排
    pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width, height: 60) do
      # 左側：捐款收據標題
      pdf.fill_color COLORS[:dark_red]
      pdf.text_box "捐款收據",
                   at: [0, pdf.bounds.top],
                   size: 28,
                   style: :bold

      # 右側：協會資訊
      pdf.fill_color COLORS[:dark_gray]
      pdf.text_box ORGANIZATION_NAME,
                   at: [0, pdf.bounds.top],
                   width: pdf.bounds.width,
                   size: 16,
                   style: :bold,
                   align: :right

      pdf.fill_color COLORS[:medium_gray]
      pdf.text_box ORGANIZATION_ADDRESS,
                   at: [0, pdf.bounds.top - 25],
                   width: pdf.bounds.width,
                   size: 11,
                   align: :right
    end

    pdf.move_down 20

    # 金色分隔線
    pdf.stroke_color COLORS[:gold]
    pdf.line_width 2
    pdf.stroke_horizontal_line 0, pdf.bounds.width, at: pdf.cursor

    pdf.move_down 30
  end

  def draw_details_section(pdf)
    left_width = (pdf.bounds.width - 30) / 2
    start_y = pdf.cursor

    # 左側：收據資訊
    pdf.bounding_box([0, start_y], width: left_width) do
      draw_section_title(pdf, "收據資訊")
      draw_detail_row(pdf, "收據編號", @donation.receipt_number)
      draw_detail_row(pdf, "捐款日期", format_date(@donation.paid_at || @donation.created_at))
      draw_detail_row(pdf, "開立日期", format_date(Time.current))
    end

    # 右側：捐款人資訊
    pdf.bounding_box([left_width + 30, start_y], width: left_width) do
      draw_section_title(pdf, "捐款人資訊")
      draw_detail_row(pdf, "功德芳名", @donation.donor_name)
      draw_detail_row(pdf, "聯絡電話", @donation.phone) if @donation.phone.present?
      draw_detail_row(pdf, "電子信箱", @donation.email) if @donation.email.present?
    end

    pdf.move_cursor_to start_y - 120
  end

  def draw_section_title(pdf, title)
    pdf.fill_color COLORS[:medium_gray]
    pdf.text title, size: 12, style: :bold
    pdf.move_down 3
    pdf.stroke_color COLORS[:light_gray]
    pdf.line_width 0.5
    pdf.stroke_horizontal_line 0, pdf.bounds.width, at: pdf.cursor
    pdf.move_down 12
  end

  def draw_detail_row(pdf, label, value)
    pdf.fill_color COLORS[:medium_gray]
    pdf.text_box label,
                 at: [0, pdf.cursor],
                 width: 80,
                 size: 11

    pdf.fill_color COLORS[:dark_gray]
    pdf.text_box value.to_s,
                 at: [85, pdf.cursor],
                 width: pdf.bounds.width - 85,
                 size: 11,
                 style: :bold

    pdf.move_down 20
  end

  def draw_line_items(pdf)
    pdf.move_down 20

    # 表格標題列
    header_data = [["項目", "說明", "金額"]]

    pdf.fill_color COLORS[:light_gray]
    pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 30

    pdf.fill_color COLORS[:dark_gray]
    pdf.table(header_data, width: pdf.bounds.width, position: :center) do |table|
      table.cells.borders = [:bottom]
      table.cells.border_color = COLORS[:gold]
      table.cells.border_width = 2
      table.cells.padding = [8, 10]
      table.cells.size = 11
      table.cells.font_style = :bold
      table.column(2).align = :right
      table.column(0).width = 120
      table.column(2).width = 120
    end

    # 資料列
    item_data = [[
      donation_type_name,
      @donation.prayer.presence || "一般捐獻",
      "NT$ #{number_with_delimiter(@donation.amount)}"
    ]]

    pdf.fill_color COLORS[:dark_gray]
    pdf.table(item_data, width: pdf.bounds.width, position: :center) do |table|
      table.cells.borders = [:bottom]
      table.cells.border_color = COLORS[:light_gray]
      table.cells.padding = [12, 10]
      table.cells.size = 11
      table.column(2).align = :right
      table.column(0).width = 120
      table.column(2).width = 120
    end

    # 合計列
    pdf.fill_color COLORS[:cream]
    pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 35

    total_data = [["", "合計", "NT$ #{number_with_delimiter(@donation.amount)}"]]

    pdf.fill_color COLORS[:dark_gray]
    pdf.table(total_data, width: pdf.bounds.width, position: :center) do |table|
      table.cells.borders = [:bottom]
      table.cells.border_color = COLORS[:gold]
      table.cells.border_width = 2
      table.cells.padding = [10, 10]
      table.cells.size = 12
      table.cells.font_style = :bold
      table.column(1).align = :right
      table.column(2).align = :right
      table.column(0).width = 120
      table.column(2).width = 120
    end
  end

  def draw_stamp(pdf)
    stamp_path = Rails.root.join(STAMP_IMAGE)
    return unless File.exist?(stamp_path)

    pdf.move_down 40

    # 印章放在右側
    pdf.image stamp_path,
              width: 100,
              position: :right
  end

  def draw_footer(pdf)
    pdf.move_down 40

    # 分隔線
    pdf.stroke_color COLORS[:light_gray]
    pdf.line_width 0.5
    pdf.stroke_horizontal_line 0, pdf.bounds.width, at: pdf.cursor

    pdf.move_down 20

    # 感謝文字
    pdf.fill_color COLORS[:medium_gray]
    pdf.text "感謝您的善心捐獻，功德無量！", size: 12, align: :center
    pdf.move_down 5
    pdf.text "本收據僅作為捐款證明，請妥善保存。", size: 11, align: :center
  end

  def donation_type_name
    I18n.t("donation_types.#{@donation.donation_type}", default: @donation.donation_type)
  end

  def format_date(time)
    return "" if time.nil?
    time.strftime("%Y年%m月%d日")
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
