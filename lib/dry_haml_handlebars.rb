require "dry_haml_handlebars/version"
require "v8"
require "handlebars_assets"
require 'haml'
require "dry_haml_handlebars/handler"
require "dry_haml_handlebars/register"
require "haml-rails"
require "rabl"
require "gon"
require_relative "action_view/base"
require_relative "action_view/helpers/capture_helper"
require_relative "action_controller/base"

module DryHamlHandlebars
  
  class Railtie < Rails::Railtie
    
    config.before_configuration do |app|
      app.config.autoload_paths += %W(#{app.config.root}/app/views)
    end
    
    config.to_prepare do
      DryHamlHandlebars.load_all_partials if Rails.env.to_sym == :production
      DryHamlHandlebars.load_all_helpers
    end
    
  end
  
  class ContentCache
    
    attr_accessor :store, :index
    
    def initialize
      @store = []
    end
    
    def add_item(name, path)
      item   = ContentItem.new(name.to_sym, path.to_s)
      @store << item
    end
    
    def remove_item(item)
      @store.delete item
    end
    
    def clear
      initialize
    end
  
  end
  
  class ContentItem
    
    attr_accessor :content
    attr_reader   :name, :path
    
    def initialize(name, path)
      @name, @path = name, path
    end
    
  end
  
  @content_cache = ContentCache.new
  
  def self.content_cache
    @content_cache
  end
  
end
