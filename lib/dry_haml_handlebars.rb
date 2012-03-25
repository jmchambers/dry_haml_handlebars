require "dry_haml_handlebars/version"
require "haml-rails"
require "handlebars"
require "dry_haml_handlebars/asset_helper"
require "draper"
require_relative "draper/base" #patch
require_relative "draper/handlebar_helpers"

ActionView::Base.send :include, DryHamlHandlebars::AssetHelper

module DryHamlHandlebars
  class Railtie < Rails::Railtie
    config.before_configuration do |app|
      app.config.autoload_paths += %W(#{app.config.root}/app/views)
    end
  end
end