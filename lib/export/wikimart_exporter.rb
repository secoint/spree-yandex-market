module Export
  class WikimartExporter < YandexMarketExporter
    def initialize
      @utms = '?utm_source=wikimart&utm_medium=yml&utm_campaign=yml'
    end
  end
end