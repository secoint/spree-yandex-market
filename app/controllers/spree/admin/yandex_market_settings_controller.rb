# -*- coding: utf-8 -*-
class Spree::Admin::YandexMarketSettingsController < Spree::Admin::BaseController  
  before_filter :get_config
  
  def show
    @taxons =  Spree::Taxon.roots
  end
  
  def general
    @taxons =  Spree::Taxon.roots
  end
  
  def currency
  end
  
  def ware_property
    @properties = Spree::Property.all
  end
  
  def export_files
    directory = File.join(Rails.root, 'public', 'yandex_market', '**', '*')
    # нельзя вызывать стат, не удостоверившись в наличии файла!!111
    @export_files =  Dir[directory].map {|x| [File.basename(x), (File.file?(x) ? File.mtime(x) : 0)] }.
      sort{|x,y| y.last <=> x.last }
    e = @export_files.find {|x| x.first == "yandex_market.xml" }
    @export_files.reject! {|x| x.first == "yandex_market.xml" }
    @export_files.unshift(e) unless e.blank?
    
    directory = File.join(Rails.root, 'public', 'wikimart', '**', '*')
    @export_files_wikimart =  Dir[directory].map {|x| [File.basename(x), (File.file?(x) ? File.mtime(x) : 0)] }.
      sort{|x,y| y.last <=> x.last }
    e = @export_files_wikimart.find {|x| x.first == "wikimart.xml" }
    @export_files_wikimart.reject! {|x| x.first == "wikimart.xml" }
    @export_files_wikimart.unshift(e) unless e.blank?
  end
  
  def run_export
    command = case params[:exporter]
    when 'yandex_market'
      %{cd #{Rails.root} && RAILS_ENV=#{Rails.env} rake spree_yandex_market:generate_ym &}
    when 'wikimart'
      %{cd #{Rails.root} && RAILS_ENV=#{Rails.env} rake spree_yandex_market:generate_wikimart &}
    end
    
    logger.info "[ yandex market ] Запуск формирование файла экспорта из блока администрирования "
    logger.info "[ yandex market ] команда - #{command} "
    system command
    flash[:notice] = "Обновите страницу через несколько минут."
    redirect_to export_files_admin_yandex_market_settings_url
  end
  
  def update   
    @config.attributes = params[:preferences]
    @config.save!
    
    respond_to do |format|
      format.html {
        redirect_to admin_yandex_market_settings_path
      }
    end
  end

  private

  def get_config
    @config = Spree::YandexMarket::Config.instance
  end
end
