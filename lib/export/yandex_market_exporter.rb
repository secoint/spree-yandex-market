# -*- coding: utf-8 -*-
require 'nokogiri'

module Export
  class YandexMarketExporter
    include Spree::Core::Engine.routes.url_helpers
    attr_accessor :host, :currencies
    
    DEFAULT_OFFER = "simple"

    def helper
      @helper ||= ApplicationController.helpers
    end
    
    def export
      @config = Spree::YandexMarket::Config.instance
      @host = @config.preferred_url.sub(%r[^http://],'').sub(%r[/$], '')
      ActionController::Base.asset_host = @config.preferred_url
      
      @currencies = @config.preferred_currency.split(';').map{|x| x.split(':')}
      @currencies.first[1] = 1
      
      # Nokogiri::XML::Builder.new({ :encoding =>"utf-8"}, SCHEME) do |xml|
      Nokogiri::XML::Builder.new(:encoding =>"utf-8") do |xml|
        xml.doc.create_internal_subset('yml_catalog',
          nil,
          "shops.dtd"
        )

        xml.yml_catalog(:date => Time.now.to_s(:ym)) {
          
          xml.shop { # описание магазина
            xml.name    @config.preferred_short_name
            xml.company @config.preferred_full_name
            xml.url     path_to_url('')
            
            xml.currencies { # описание используемых валют в магазине
              @currencies && @currencies.each do |curr|
                opt = {:id => curr.first, :rate => curr[1] }
                opt.merge!({ :plus => curr[2]}) if curr[2] && ["CBRF","NBU","NBK","CB"].include?(curr[1])
                xml.currency(opt)
              end
            }        
            
            xml.categories { # категории товара
              Spree::Taxonomy.all.each do |taxonomy|
                taxonomy.root.self_and_descendants.each do |cat|
                  @cat_opt = { :id => cat.id }
                  @cat_opt.merge!({ :parentId => cat.parent_id}) unless cat.parent_id.blank?
                  xml.category(@cat_opt){ xml  << cat.name }
                end
              end
            }
            
            xml.offers { # список товаров
              products = Spree::Product.active.master_price_gte(0.001)
              products = products.on_hand if @config.preferred_wares == "on_hand"
              products = products.where(:export_to_yandex_market => true).group_by_products_id
              products.each do |product|
                offer(xml, product, product.taxons.first) unless product.taxons.empty?
              end
            }
          }
        } 
      end.to_xml
      
    end
    
    
    private
    
    def path_to_url(path)
      "http://#{@host.sub(%r[^http://],'')}/#{path.sub(%r[^/],'')}"
    end
    
    def offer(xml,product, cat)
      offer_simple(xml, product, cat)
    end
    
    def shared_xml(xml, product, cat)
      xml.url product_url(product, :host => @host)
      xml.price product.price
      xml.currencyId @currencies.first.first
      xml.categoryId cat.id
      xml.picture path_to_url(CGI.escape(product.images.first.attachment.url(:product, false))) unless product.images.empty?
    end
    
    def individual_xml(xml, product, cat, product_properties = {})
      xml.delivery            true
      xml.local_delivery_cost @config.preferred_local_delivery_cost unless @config.preferred_local_delivery_cost.blank?
      xml.name                product.name
      xml.vendorCode          product_properties[@config.preferred_vendor_code] if product_properties[@config.preferred_country_of_manufacturer].present?
      xml.description         product.description if product.description.present?
      xml.country_of_origin   product_properties[@config.preferred_country_of_manufacturer] if product_properties[@config.preferred_country_of_manufacturer].present?
      xml.downloadable        false
    end

    def offer_simple(xml, product, cat)
      product_properties = { }
      product.product_properties.map {|x| product_properties[x.property_name] = x.value }
      opt = { :id => product.id,  :available => product.available? }
      xml.offer(opt) {
        shared_xml(xml, product, cat)
        individual_xml(xml, product, cat, product_properties)
      }
    end
    
  end
end
