require "dry_haml_handlebars/version"
require "v8"
require "handlebars_assets"
require 'haml'
require "dry_haml_handlebars/handler"
require "dry_haml_handlebars/register"
require "haml-rails"
require "rabl"
require "gon"

module DryHamlHandlebars
  
  class Railtie < Rails::Railtie
    
    config.before_configuration do |app|
      app.config.autoload_paths += %W(#{app.config.root}/app/views)
    end
    
    # config.to_prepare do
      # # this is only called once in dev mode and not on every request as it is meant to
      # # just manually call DryHamlHandlebars.prepare_handlebars if you change/add a helper
      # # see https://github.com/rails/rails/issues/7152
      # DryHamlHandlebars.prepare_handlebars
    # end
    
    initializer "dry_haml_handlebars.configure" do |app|

      ActiveSupport.on_load :action_view do
        require 'dry_haml_handlebars/view_helpers/action_view'
        include DryHamlHandlebars::ViewHelpers::ActionView
      end
      
      ActiveSupport.on_load :action_controller do
        require 'dry_haml_handlebars/controller_helpers/action_controller'
        include DryHamlHandlebars::ControllerHelpers::ActionController
      end
      
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
  
  def self.prepare_handlebars(additional_javascripts = [])
    
    additional_javascripts = Array.wrap(additional_javascripts)
    
    compile_all_helper_coffeescripts unless ["development", "test"].include?(Rails.env.to_s)
    #load_i18n if defined? SimplesIdeias::I18n
    
    hbs_context = HandlebarsAssets::Handlebars.send(:context)
    
    templates_and_partials = Dir.glob(Rails.root.join('app', 'assets', 'compiled_templates', '**', '*.js'))
    handlebars_helpers     = Dir.glob(Rails.root.join('app', 'assets', 'handlebars_helpers', '**', '*.js'))

    self_loading_assets = templates_and_partials + handlebars_helpers + additional_javascripts
    
    Rails.logger.info "self_loading_assets = #{self_loading_assets}"

    self_loading_assets.each do |fname|
      basename = File.basename(fname)
      File.open(fname) do |file|
        source = file.read
        source.strip!
        source.chomp!(";")
        Rails.logger.info "about to run:\nhbs_context.eval(#{source[0..50] + '...'}, #{basename})"
        hbs_context.eval(source, basename)
      end
    end
  end
  
  def self.load_i18n
    
    hbs_context = HandlebarsAssets::Handlebars.send(:context)
    
    @i18n_js_path ||= Rails.application.config.assets.paths.find { |fname| fname.match(/i18n-js-[.\d]+\/vendor\/assets\/javascripts/) }
    fname    = "#{@i18n_js_path}/i18n.js"
    source   = File.read(fname).gsub(
      "var I18n = I18n || {};",
      "this.I18n || (this.I18n = {});"
    )
    
    json_translations = SimplesIdeias::I18n.translation_segments.each_with_object({}) do |(name, segment),translations|
      translations.merge!(segment)
    end.to_json

    load_script = <<-JAVASCRIPT
      (function(){
        #{source}
        I18n.translations   = #{json_translations};
        I18n.defaultLocale  = #{I18n.default_locale.to_s.inspect};
        I18n.fallbacksRules = #{I18n.fallbacks.to_json};
        I18n.fallbacks      = true;
      }).call(this)
    JAVASCRIPT
    
    hbs_context.eval load_script
  end
  
  def self.compile_all_helper_coffeescripts
    handlebars_helpers = Dir.glob(Rails.root.join('app', 'assets', 'handlebars_helpers', '*', '*.coffee'))
    js_directory       = Rails.root.join('app', 'assets', 'handlebars_helpers', 'javascripts').to_s
    handlebars_helpers.each do |coffee_path|
      
      #get expected js path
      filename   = File.basename(coffee_path).split('.').first + '.js'
      js_path    = File.join(js_directory, filename)
      
      #see if the js exists and is older than the coffee
      unless File.exist?(js_path) and File.mtime(js_path) >= File.mtime(coffee_path)
        
        #if so, compile coffee and overwrite/create the js
        coffee     = File.read(coffee_path)
        javascript = CoffeeScript.compile(coffee).strip
        javascript = javascript[0..-2] if javascript[-1] == ';' #remove trailing semi-colon because it makes execjs.eval cry
        
        FileUtils.mkdir_p js_directory unless File.directory? js_directory
        File.open(js_path, 'w+') { |f| f.write(javascript) }
        
      end
        
    end
  end
  
end
