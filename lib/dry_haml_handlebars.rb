require "dry_haml_handlebars/version"
require "v8"
require "handlebars_assets"
require 'haml'
require "dry_haml_handlebars/handler"
require "dry_haml_handlebars/register"
require "haml-rails"
require "rabl"

module DryHamlHandlebars
  class Railtie < Rails::Railtie
    
    config.before_configuration do |app|
      app.config.autoload_paths += %W(#{app.config.root}/app/views)
    end
    
    config.to_prepare do
      DryHamlHandlebars.load_all_partials if Rails.env.to_s == "production"
      DryHamlHandlebars.load_all_helpers
    end
    
  end
end
