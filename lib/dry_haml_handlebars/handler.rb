module DryHamlHandlebars
  
  require 'haml/template/plugin'
  
  class Handler < Haml::Plugin
    
    def self.call(template)
              
      view_match         = template.identifier.match(/^#{Rails.root.join('app', 'views')}[\/](?<view_path>\w+)[\/](?<view_name>\w+).html/)
      relative_view_path = view_match[:view_path]
      original_view_name = view_match[:view_name]
      view_type          = get_view_type(template, relative_view_path, original_view_name)
      
      return super if [:layout, :ignored_partial].include? view_type

      view_name, partial_name = get_safe_view_names(original_view_name, view_type)
      rabl_path, template_path, compiled_template_path = generate_file_names(relative_view_path, original_view_name, view_name)
      
      env = Rails.env.to_sym

      if [:development, :test].include?(env) or !File.exist?(compiled_template_path)
        rendered_haml = <<-RUBY
          rendered_haml = eval(%q( #{super} )).html_safe
        RUBY
      else
        rendered_haml = nil
      end
      
      runner = Runner.new(
        template,
        rendered_haml,
        view_type,
        view_name,
        partial_name,
        relative_view_path,
        rabl_path,
        template_path,
        compiled_template_path
      )
      
      runner.run
        
    end
      
    def self.get_view_type(template, relative_view_path, original_view_name)
      
      #we have 4 types of view;
      # 1) layout           - always handled by haml, no hbs/js versions are generated
      # 2) template         - rendered as handlebars, we expect there to be html.haml AND .rabl for the JSON
      # 3) partial          - pulled into view by handlebars syntax {{>name}}
      # 4) ignored_partial  - a regular partial, it will be rendered by Haml, with no handlebars-related processing
      
      if relative_view_path == 'layouts'
        :layout
      elsif template.locals.inspect.include?("handlebars_partial")
        :partial
      elsif original_view_name.starts_with? "_"
        :ignored_partial
      else
        :template
      end
            
    end
    
    def self.get_safe_view_names(original_view_name, view_type)

      case view_type
      when :template
        view_name    = "hbs_#{original_view_name}"
        partial_name = nil
      when :partial
        view_name    = "_hbs#{original_view_name}"
        partial_name = view_name[1..-1]
      end

      return view_name, partial_name
                  
    end
    
    def self.generate_file_names(relative_view_path, original_view_name, view_name)
      
      template_partial_path           = Rails.root.join( *%w(app assets templates)          << "#{relative_view_path}" )
      compiled_template_partial_path  = Rails.root.join( *%w(app assets compiled_templates) << "#{relative_view_path}" )
      
      rabl_path               = Rails.root.join( 'app', 'views', relative_view_path, "#{original_view_name}.rabl" )
      template_path           = File.join( template_partial_path, "#{view_name}.hbs" )
      compiled_template_path  = File.join( compiled_template_partial_path, "#{view_name}.js" )
      
      FileUtils.mkdir_p template_partial_path             unless File.directory? template_partial_path
      FileUtils.mkdir_p compiled_template_partial_path    unless File.directory? compiled_template_partial_path
      
      return rabl_path, template_path, compiled_template_path
      
    end
    
    
  end
        
  class Runner
    
    def initialize(template, rendered_haml = nil, view_type, view_name, partial_name, relative_view_path, rabl_path, template_path, compiled_template_path)
      @template                 = template
      @rendered_haml            = rendered_haml
      @view_type                = view_type
      @view_name                = view_name
      @partial_name             = partial_name
      @relative_view_path       = relative_view_path
      @rabl_path                = rabl_path
      @template_path            = template_path
      @compiled_template_path   = compiled_template_path
    end
    
    def run
      
      content_cache = DryHamlHandlebars.content_cache
      out = []
    
      if @rendered_haml
      
        out << @rendered_haml
        out << compile_hbs
        
        case @view_type
        when :template
          
          out << name_template
          out << gen_template_loader
          
        when :partial
          
          out << name_partial
          out << gen_partial_loader
          
        end

        out << write_asset_files
                  
      else #if we don't have any rendered haml (we're probably in production)

        out << name_template
        
      end
      
      out << load_template
      
      case @view_type
      when :template
        
        out << render_rabl
        out << set_gon_variable
        
        if content_cache.store.present? #do we need to render some content for another view?

          content_cache.store.each do |item|
            
            name = item.name
            path = item.path
            content_cache.remove_item(item)
            
            #NOTE: this call will overwrite all eval'd variables set below, except for template_names
            #we store this in a stack and pop the last name when we get to render_template()
            #it doesn't matter about the other variables as we're finished with them by this stage
            #and it keeps the eval code simpler if we just reuse them
            
            out << render_content_for(name, path)
            
          end
          content_cache.clear #just to be sure
          
        end
        
        out << render_template
        
      when :partial
        
        out << render_handlebars_partial_command
        
      end
      
      out.join("\n")


    end
    
    def compile_hbs
      <<-RUBY
        compiled_hbs = HandlebarsAssets::Handlebars.precompile( rendered_haml )
      RUBY
    end
    
    def name_template
      <<-RUBY
        template_names ||= []
        template_names << '#{File.join(@relative_view_path, @view_name).to_s}'
      RUBY
    end
    
    def name_partial
      <<-RUBY
        partial_name  = '#{@partial_name}'
      RUBY
    end
    
    def gen_template_loader
      <<-'RUBY'
        hbs_loader = "(function() {
          this.HandlebarsTemplates || (this.HandlebarsTemplates = {});
          this.HandlebarsTemplates['#{template_names.last}'] = Handlebars.template(#{compiled_hbs});
          return HandlebarsTemplates['#{template_names.last}'];
        }).call(this)"
      RUBY
    end
    
    def gen_partial_loader
      <<-'RUBY'
        hbs_loader = "(function() {
          this.Handlebars.registerPartial('#{partial_name}', Handlebars.template(#{compiled_hbs}));
        }).call(this)"
      RUBY
    end
    
    def write_asset_files
      <<-RUBY
        File.open('#{@template_path}',          'w+') {|f| f.write(rendered_haml) }
        File.open('#{@compiled_template_path}', 'w+') {|f| f.write(hbs_loader) }
      RUBY
    end
    
    def load_template
      <<-RUBY
        hbs_context = HandlebarsAssets::Handlebars.send(:context)
        File.open('#{@compiled_template_path}') do |file|
          hbs_context.eval(file.read, '#{@view_name}.js')
        end
      RUBY
    end
    
    def render_rabl
      
      if File.exist? @rabl_path
    
        rabl_handler  = ActionView::Template.handler_for_extension :rabl
        rabl_template = ActionView::Template.new([], @rabl_path, rabl_handler, {:locals => @template.locals})
        rabl_call     = rabl_handler.call rabl_template

        <<-RUBY
          rendered_rabl = eval(%q( #{rabl_call} )).html_safe
        RUBY
        
      else
        
        <<-RUBY
          rendered_rabl ||= '{}'.html_safe
        RUBY
        
      end
      
    end
    
    def set_gon_variable
      <<-RUBY
        Gon.request = request.object_id
        Gon.request_env = request.env
        Gon.set_variable('view_data', JSON.parse(rendered_rabl))
      RUBY
    end
    
    def render_template
      <<-'RUBY'
        current_template_name = template_names.pop
        hbs_context.eval( "HandlebarsTemplates['#{current_template_name}'](#{rendered_rabl})" )
      RUBY
    end
    
    def render_handlebars_partial_command
      <<-RUBY
        '{{> #{@partial_name}}}'.html_safe
      RUBY
    end
    
    def render_content_for(name, path)
      
      haml_handler  = ActionView::Template.handler_for_extension :haml
      haml_source   = File.read(path)
      haml_template = ActionView::Template.new(haml_source, path, haml_handler, {})
      haml_call     = haml_handler.call haml_template

      <<-RUBY
        @view_flow.set( :#{name}, eval(%q( #{haml_call} )).html_safe )
      RUBY
      
    end
      
    
  end
  
end







