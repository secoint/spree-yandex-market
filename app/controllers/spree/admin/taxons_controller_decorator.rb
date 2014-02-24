Spree::Admin::TaxonsController.class_eval do
  after_filter :update_descendants_ym_flag, :only => :update

  private

  def update_descendants_ym_flag
    taxon = @taxon || Taxon.find(params[:id])
    taxon.descendants.each do |t|
      t.export_to_yandex_market = taxon.export_to_yandex_market
      t.save!
    end
  end
end
