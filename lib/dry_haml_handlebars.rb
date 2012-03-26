require "dry_haml_handlebars/version"
require "tilt"
require "execjs"
require "handlebars_assets"
#require "draper"
#require_relative "draper/base" #patch
#require_relative "draper/handlebar_helpers"
require 'haml'
require "dry_haml_handlebars/asset_helper"
require "dry_haml_handlebars/handler"
require "dry_haml_handlebars/register"
require "haml-rails"
require "rabl"

module DryHamlHandlebars
  class Railtie < Rails::Railtie
    config.before_configuration do |app|
      app.config.autoload_paths += %W(#{app.config.root}/app/views)
    end
  end
end
