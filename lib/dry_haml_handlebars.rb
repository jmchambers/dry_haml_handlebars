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
  
  def self.load_all_partials
    
    hbs_context = HandlebarsAssets::Handlebars.send(:context)
    
    partials = Dir.glob(Rails.root.join('app', 'assets', 'compiled_templates', '*', '_*.js'))
    partials.each do |fname|
      basename = File.basename(fname)
      File.open(fname) do |file|
        hbs_context.eval(file.read, basename)
      end
    end
    
  end
  
  def self.load_all_helpers
    
    compile_all_coffeescripts

    #NOTE: only a change to a view will make rail pick up on a change to the helpers     
    hbs_context = HandlebarsAssets::Handlebars.send(:context)

    handlebars_helpers = Dir.glob(Rails.root.join('app', 'assets', 'handlebars_helpers', '*', '*.js'))
    handlebars_helpers.each do |fname|
      basename = File.basename(fname)
      File.open(fname) do |file|
        source = file.read.strip
        source = source[0..-2] if source[-1] == ';' #remove trailing semi-colon because it makes execjs.eval cry
        hbs_context.eval(source, basename)
        hbs_context.eval('HandlebarsHelpers.load_helpers()')
      end
    end

  end
  
  def self.compile_all_coffeescripts
    handlebars_helpers = Dir.glob(Rails.root.join('app', 'assets', 'handlebars_helpers', '*', '*.coffee'))
    js_directory       = Rails.root.join('app', 'assets', 'handlebars_helpers', 'javascripts').to_s
    handlebars_helpers.each do |coffee_path|
      
      #get expected js path
      filename   = File.basename(coffee_path).split('.').first + '.js'
      js_path    = File.join(js_directory, filename)
      
      #see if the js exists and is older than the coffee
      unless File.exist?(js_path) and File.mtime(js_path) > File.mtime(coffee_path)
        
        #if so, compile coffee and overwrite/create the js
        coffee     = File.read(coffee_path)
        javascript = CoffeeScript.compile(coffee)
        
        FileUtils.mkdir_p js_directory unless File.directory? js_directory
        File.open(js_path, 'w+') { |f| f.write(javascript) }
        
      end
        
    end
  end
  
end
