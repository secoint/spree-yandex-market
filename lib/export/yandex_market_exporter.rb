# -*- coding: utf-8 -*-
require 'nokogiri'

module Export
  class YandexMarketExporter
    include Rails.application.routes.url_helpers
    include ActionView::Helpers::SanitizeHelper

    attr_accessor :host, :currencies

    def initialize
      @utms = '?utm_source=yandex&utm_medium=market&utm_campaign=market'
    end

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
            xml.name    @config.preferred_short_name
            xml.company @config.preferred_full_name
            xml.url     path_to_url('')
            
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
              products = Product.in_taxon(@preferred_category).active.master_price_gte(0.001)
              products = products.uniq.select { |p| p.has_stock? && p.cat.export_to_yandex_market && p.export_to_yandex_market }
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
      variants = product.variants.select { |v| v.count_on_hand > 0 }
      count = variants.length

      gender = case product.gender
        when 1 then 'Мужской'
        when 2 then 'Женский'
        else ''
      end

      variants.each do |variant|
        opt = { :type => 'vendor.model', :available => true }

        opt[:id] = count > 1 ? variant.id : product.id
        opt[:group_id] = product.id if count > 1
        
        xml.offer(opt) do
          xml.url "http://#{@host}/id/#{product.id}#{@utms}"
          xml.price variant.price
          xml.currencyId @currencies.first.first
          xml.categoryId product.cat.id
          product.images.each do |image|
            xml.picture image_url(image)
          end
          xml.delivery true
          xml.vendor product.brand.name if product.brand
          xml.vendorCode product.sku
          xml.model product.name
          xml.description strip_tags(product.description) if product.description
          xml.country_of_origin product.country.name if product.country
          variant.option_values.each do |ov|
            unless ov.presentation == 'Без размера'
              xml.param ov.presentation, :name => ov.option_type.presentation, :unit => 'BRAND'
            end
          end
          xml.param product.colour, :name => 'Цвет'
          xml.param gender, :name => 'Пол' if gender.present?
          xml.param 'Детский', :name => 'Возраст'
        end
      end
    end

    def path_to_url(path)
      "http://#{@host.sub(%r[^http://],'')}/#{path.sub(%r[^/],'')}"
    end

    def image_url(image)
      "#{asset_host(image.to_s)}/#{CGI.escape(image.attachment.url(:large, false))}"
    end

    def asset_host(source)
      "http://assets0#{(1 + source.hash % 5).to_s + '.' + @host}"
    end
  end
end
