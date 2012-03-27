module DryHamlHandlebars
  module Register
    
    #ActionView::Base.send :include, DryHamlHandlebars::AssetHelper
    ActionView::Template.register_template_handler(:haml, DryHamlHandlebars::Handler)
    #raise "#{ActionView::Template.handler_for_extension :haml} is handling :haml"

  end
end