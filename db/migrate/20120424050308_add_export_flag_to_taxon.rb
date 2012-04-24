class AddExportFlagToTaxon < ActiveRecord::Migration
  def self.up
    add_column :taxons, :export_to_yandex_market, :boolean, :default => true,
               :null => false
  end

  def self.down
    remove_column :taxons, :export_to_yandex_market
  end
end
