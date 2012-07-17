module Export
  class OlxExporter < YandexMarketExporter
    def initialize
      @utms = '?utm_source=olx&utm_medium=yml&utm_campaign=yml'
    end
  end
end