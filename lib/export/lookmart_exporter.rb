module Export
  class LookmartExporter < YandexMarketExporter
    def initialize
      @utms = '?utm_source=lookmart&utm_medium=lookmart&utm_campaign=lookmart'
    end

    protected

    def image_url(image)
      "#{asset_host(image.to_s)}/#{CGI.escape(image.attachment.url(:original, false))}"
    end
  end
end
