module Export
  class KupitigraExporter < YandexMarketExporter
    def initialize
      @utms = '?utm_source=kupitigra&utm_medium=yml&utm_campaign=yml'
    end
  end
end