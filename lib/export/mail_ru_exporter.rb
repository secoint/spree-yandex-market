module Export
  class MailRuExporter < YandexMarketExporter
    def initialize
      @utms = '?utm_source=mailru&utm_medium=yml&utm_campaign=yml'
    end
  end
end
