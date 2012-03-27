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
        
        get_safe_view_names
        generate_file_names
        env = Rails.env.to_s
        
        out = []
        
        if ["development", "test"].include?(env) or !File.exist?(@compiled_template_filename)
          
          render_haml = <<-RUBY
                          rendered_haml = eval(%q( #{super} )).html_safe
                        RUBY
        
          out << render_haml
          out << compile_hbs
          
          if @view_type == :template
            
            out << name_template
            out << gen_template_loader
            
          elsif @view_type == :partial
            
            out << name_partial
            out << gen_partial_loader
            
          end

          out << write_asset_files
                    
        elsif env == "production"

          out << name_template
          
        else
          #raise "don't have a workflow for the #{env} environment"
        end
        
        #common actions
        out << load_template
        
        if @view_type == :template
          out << render_rabl(template)
          out << set_gon_variable
          out << render_template
        end
        
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
      
      def get_safe_view_names
      
        @view_name =  case @original_view_name
                      when "application", "index"
                        "jst_#{@original_view_name}"
                      else
                        @original_view_name
                      end
                      
        @partial_name = @original_view_name[1..-1] if @view_type == :partial
                    
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
          compiled_hbs = HandlebarsAssets::Handlebars.precompile( rendered_haml )
        RUBY
      end
      
      def name_template
        <<-RUBY
          template_name = '#{File.join(@relative_view_path, @view_name).to_s}'
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
            this.HandlebarsTemplates['#{template_name}'] = Handlebars.template(#{compiled_hbs});
            return HandlebarsTemplates['#{template_name}'];
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
        
        if File.exist? @rabl_filename
      
          rabl_handler  = ActionView::Template.handler_for_extension :rabl
          rabl_template = ActionView::Template.new([], @rabl_filename, rabl_handler, {:locals => template.locals})
          rabl_call     = rabl_handler.call rabl_template
  
          <<-RUBY
            rendered_rabl = eval(%q( #{rabl_call} )).html_safe
          RUBY
          
        else
          
          <<-RUBY
            rendered_rabl = '{}'.html_safe
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
          hbs_context.eval( "HandlebarsTemplates['#{template_name}'](#{rendered_rabl})" )
        RUBY
      end
      
    end
  end
  
  
  #DryHamlHandlebars module methods
  
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
  
end







