# -*- coding: utf-8 -*-
require 'nokogiri'

module Export
  class YandexMarketExporter
    include Rails.application.routes.url_helpers
    include ActionView::Helpers::SanitizeHelper

    attr_accessor :host, :currencies

    def helper
      @helper ||= ApplicationController.helpers
    end
    
    def export
      @config = Spree::YandexMarket::Config.instance
      @host = @config.preferred_url.sub(%r[^http://],'').sub(%r[/$], '')

      @currencies = @config.preferred_currency.split(';').map{ |x| x.split(':') }
      @currencies.first[1] = 1
      
      @preferred_category = Taxon.find_by_name(@config.preferred_category)
      unless @preferred_category.export_to_yandex_market
        raise "Preferred category <#{@preferred_category.name}> not included to export"
      end

      @categories = @preferred_category.self_and_descendants\
                    .where(:export_to_yandex_market => true)

      @categories_ids = @categories.collect { |x| x.id }
      
      Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
        xml.doc.create_internal_subset('yml_catalog', nil, 'shops.dtd')

        xml.yml_catalog(:date => Time.now.to_s(:ym)) {
          xml.shop { # описание магазина
            xml.name      @config.preferred_short_name
            xml.company   @config.preferred_full_name
            xml.url       @config.preferred_url
            xml.platform  @config.preferred_platform
            xml.version   @config.preferred_version
            xml.agency    @config.preferred_agency
            xml.email     @config.preferred_email
            
            xml.currencies { # описание используемых валют в магазине
              @currencies && @currencies.each do |curr|
                opt = { :id => curr.first, :rate => curr[1] }
                opt.merge!({ :plus => curr[2] }) if curr[2] && ["CBRF","NBU","NBK","CB"].include?(curr[1])
                xml.currency(opt)
              end
            }        
            
            xml.categories { # категории товара
              @categories_ids && @categories.each do |cat|
                @cat_opt = { :id => cat.id }
                @cat_opt.merge!({ :parentId => cat.parent_id }) unless cat.parent_id.blank?
                xml.category(@cat_opt){ xml  << cat.name }
              end
            }

            xml.offers { # список товаров
              products = Product.in_taxon(@preferred_category).active.master_price_gte(1)
              products.each do |product|
                offer_vendor_model(xml, product)
              end
            }
          }
        } 
      end.to_xml
    end
    
    protected
    
    def offer_vendor_model(xml, product)
      opt = { 
        :id         => product.id,
        :available  => (product.has_stock?) ? true : false
      }
        
      xml.offer(opt) do
        xml.url path_to_url(product.permalink)
        xml.price product.price
        xml.currencyId @currencies.first.first
        xml.categoryId product.cat.id
        product.images.take(10).each do |image|
          xml.picture path_to_url(image.attachment.url(:large, false))
        end
        xml.store true 
        xml.pickup true
        xml.delivery true
        xml.name "Настольная игра \"#{product.name}\""
        xml.description strip_tags(product.description) if product.description
        xml.param players_count_info(product), :name => "Количество игроков"
        xml.param product.age, :name => 'Рекомендуемый возраст' if product.age
        xml.param product.learning_time, :name => 'Сложность правил' if product.learning_time
        xml.param product.gaming_time, :name => 'Продолжительность игры' if product.gaming_time
      end
    end

    def path_to_url(path)
      "http://#{@host.sub(%r[^http://],'')}/#{path.sub(%r[^/],'')}"
    end
    
    def players_count_info(product)
      if product.min_players == product.max_players
        product.min_players.to_s
      elsif product.min_players && !product.max_players
        product.min_players.to_s
      else
        product.min_players.to_s << "-" << product.max_players.to_s
      end
    end
  end
end
