module DryHamlHandlebars
  
  require 'haml/template/plugin'
  
  class Handler < Haml::Plugin
    
    def self.call(template)
      
      puts "locals are: #{template.locals}; template is #{template}; and self is #{self}"
      
      view_filename       = template.identifier
      view_match          = template.identifier.match(/^#{Rails.root.join('app', 'views')}[\/](?<view_path>\w+)[\/](?<view_name>\w+).html/)
      relative_view_path  = view_match[:view_path]
      original_view_name  = view_match[:view_name]
     
      #TODO: detect when we have a layout, and ONLY call that template with JSON data, as all others are embedded in it
      
      #avoid clash with sprocket's special file names
      view_name = case original_view_name
                  when "application", "index"
                    "jst_#{original_view_name}"
                  else
                    original_view_name
                  end
                  
      if relative_view_path == 'layouts'
        return super
      end

      rendered_haml = "\n rendered_haml = eval(%q( #{super} )).html_safe \n"
      
      rabl_filename = Rails.root.join( 'app', 'views', relative_view_path, "#{original_view_name}.rabl" )
      
      rendered_rabl = if File.exist? rabl_filename
                      
                        rabl_handler  = ActionView::Template.handler_for_extension :rabl
                        rabl_template = ActionView::Template.new([], rabl_filename, rabl_handler, {:locals => template.locals})
                        rabl_call     = rabl_handler.call rabl_template
                        
                        "\n rendered_rabl = eval(%q( #{rabl_call} )).html_safe \n"
                        
                      else
                        "\n rendered_rabl ||= '{}'; \n" #reuse from last call #TODO sort thi
                      end
      
      template_path          = Rails.root.join( *%w(app assets templates)          << "#{relative_view_path}" )
      compiled_template_path = Rails.root.join( *%w(app assets compiled_templates) << "#{relative_view_path}" )
      
      FileUtils.mkdir_p template_path             unless File.directory? template_path
      FileUtils.mkdir_p compiled_template_path    unless File.directory? compiled_template_path
      
      template_filename = Rails.root.join( template_path, "#{view_name}.hbs" )
      compiled_template_filename = Rails.root.join( compiled_template_path, "#{view_name}.js" )
      
      #foo = "<div>hello foo {{thing}}</div>"
      bar = "console.log('bar!')"
      
      write_templates = <<-RUBY
                          File.open('#{template_filename}',          'w+') {|f| f.write(rendered_haml) }
                          File.open('#{compiled_template_filename}', 'w+') {|f| f.write(hbs_loader) }
                        RUBY
      
      precompiled_hbs  =  "\n precompiled_hbs = HandlebarsAssets::Handlebars.precompile( rendered_haml ) \n"

      template_name = "\n template_name = '#{File.join(relative_view_path, view_name).to_s}' \n"
      
      gen_hbs_loader =  %q{
                            hbs_loader = "(function() {
                              this.HandlebarsTemplates || (this.HandlebarsTemplates = {});
                              this.HandlebarsTemplates['#{template_name}'] = Handlebars.template(#{precompiled_hbs});
                              return HandlebarsTemplates['#{template_name}'];
                            }).call(this);"
                          }
      
      #TODO: add setup steps to register partials and helpers i.e. build the same environment here that the client has
      
      load_template  = 'hbs_context = HandlebarsAssets::Handlebars.send(:context);
                        hbs_context.eval( "Handlebars.template(#{precompiled_hbs})(#{rendered_rabl})" );'
                          
      #rendered_template =   ' rendered_template = hbs_context.eval( "HandlebarsTemplates['#{template_name}'](#{rendered_rabl})" ); '
      
      #render_haml
      out = rendered_haml     + 
            rendered_rabl     +
            precompiled_hbs   +
            template_name     +
            gen_hbs_loader    +
            write_templates   +
            load_template     #+
            #rendered_template +
            #"\n return rendered_haml \n"
      
      #raise out
      
    end
    
  end
end














