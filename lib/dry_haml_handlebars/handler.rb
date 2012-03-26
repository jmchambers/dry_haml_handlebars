module DryHamlHandlebars
  
  require 'haml/template/plugin'
  
  class Handler < Haml::Plugin
  
    class << self
    
      def call(template)
        
        view_match           = template.identifier.match(/^#{Rails.root.join('app', 'views')}[\/](?<view_path>\w+)[\/](?<view_name>\w+).html/)
        @relative_view_path  = view_match[:view_path]
        @original_view_name  = view_match[:view_name]
        get_view_type
        
        return super if @view_type == :layout
        
        get_safe_view_name
        generate_file_names
        env = Rails.env.to_s
        
        if ["development", "test"].include?(env) or !File.exist?(@compiled_template_filename)
          
          render_haml = <<-RUBY
                          rendered_haml = eval(%q( #{super} )).html_safe
                        RUBY
        
          out =  [render_haml]
          out << compile_hbs
          out << name_templates
          out << gen_template_loader   if @view_type == :template
          out << gen_partial_loader    if @view_type == :partial
          out << write_asset_files
                    
        elsif env == "production"
          
          #no special actions for now

        else
          
          raise "don't have a workflow for the #{env} environment"

        end
        
        #common actions
        #TODO: add setup steps to register partials and helpers i.e. build the same environment here that the client has

        out << load_template
        out << render_rabl(template)   if @view_type == :template and File.exist? @rabl_filename
        out << render_template         if @view_type == :template
        out.join("\n")

      end
      
      
     
      
      def get_view_type
        
        #we have three types of view;
        # 1) layout   - always handled by haml, no hbs/js versions are generated
        # 2) template - rendered as handlebars, we expect there to be html.haml AND .rabl for the JSON
        # 3) partial  - pulled into view by handlebars syntax {{>name}}
        
        @view_type =  if @relative_view_path == 'layouts'
                        :layout
                      elsif @original_view_name.starts_with? "_"
                        :partial
                      else
                        :template
                      end
        
      end
      
      def get_safe_view_name
      
        @view_name =  case @original_view_name
                      when "application", "index"
                        "jst_#{@original_view_name}"
                      else
                        @original_view_name
                      end
                    
      end
      
      def generate_file_names
        
        template_path                = Rails.root.join( *%w(app assets templates)          << "#{@relative_view_path}" )
        compiled_template_path       = Rails.root.join( *%w(app assets compiled_templates) << "#{@relative_view_path}" )
        
        @rabl_filename               = Rails.root.join( 'app', 'views', @relative_view_path, "#{@original_view_name}.rabl" )
        @template_filename           = Rails.root.join( template_path, "#{@view_name}.hbs" )
        @compiled_template_filename  = Rails.root.join( compiled_template_path, "#{@view_name}.js" )
        
        FileUtils.mkdir_p template_path             unless File.directory? template_path
        FileUtils.mkdir_p compiled_template_path    unless File.directory? compiled_template_path
        
      end
      
      def compile_hbs
        <<-RUBY
          precompiled_hbs = HandlebarsAssets::Handlebars.precompile( rendered_haml )
        RUBY
      end
      
      def name_templates
        <<-RUBY
          template_name = '#{File.join(@relative_view_path, @view_name).to_s}'
        RUBY
      end
      
      def gen_template_loader
        <<-'RUBY'
          hbs_loader = "(function() {
            this.HandlebarsTemplates || (this.HandlebarsTemplates = {});
            this.HandlebarsTemplates['#{template_name}'] = Handlebars.template(#{precompiled_hbs});
            return HandlebarsTemplates['#{template_name}'];
          }).call(this)"
        RUBY
      end
      
      def gen_partial_loader
        <<-'RUBY'
          hbs_loader = "(function() {
            Handlebars.registerPartial(#{template_name}, Handlebars.template(#{precompiled_hbs}));
            this.HandlebarsTemplates || (this.HandlebarsTemplates = {});
            this.HandlebarsTemplates['#{template_name}'] = Handlebars.template(#{precompiled_hbs});
            return HandlebarsTemplates['#{template_name}'];
          }).call(this)"
        RUBY
      end
      
      def write_asset_files
        <<-RUBY
          File.open('#{@template_filename}',          'w+') {|f| f.write(rendered_haml) }
          File.open('#{@compiled_template_filename}', 'w+') {|f| f.write(hbs_loader) }
        RUBY
      end
      
      def load_template
        <<-RUBY
          hbs_context = HandlebarsAssets::Handlebars.send(:context)
          File.open('#{@compiled_template_filename}') do |file|
            hbs_context.eval(file.read, '#{@view_name}.js')
          end
        RUBY
      end
      
      def render_rabl(template)
      
        rabl_handler  = ActionView::Template.handler_for_extension :rabl
        rabl_template = ActionView::Template.new([], @rabl_filename, rabl_handler, {:locals => template.locals})
        rabl_call     = rabl_handler.call rabl_template

        <<-RUBY
          rendered_rabl = eval(%q( #{rabl_call} )).html_safe
        RUBY
        
      end
      
      def render_template
        <<-'RUBY'
          hbs_context.eval( "HandlebarsTemplates['#{template_name}'](#{rendered_rabl})" )
        RUBY
      end
      
    end
  end
end







