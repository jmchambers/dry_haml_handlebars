module DryHamlHandlebars
  
  INDENT      = /\A(?<indent>\s*)/
  CONTENT     = /#{INDENT}\S+.*\Z/
  BLOCK_START = /(?<start>#{INDENT}{{#(?<keyword>\w+))/
  
  require 'haml/template/plugin'
  
  def self.dedent_hbs(source)
    lines = source.lines.to_a
    mod_lines = lines.clone
    lines.each_with_index do |line1, i1|
      
      if (l1_match = line1.match BLOCK_START)
        
        l1_index  = i1
        l1_indent = l1_match[:indent] ? l1_match[:indent].length : 0
        l1_text   = l1_match[:start]
        
        #binding.pry if i1 == 7
    
        next_match = nil
        next_line = lines[l1_index+1..-1].detect { |l| next_match = l.match(CONTENT) }
        
        next unless next_match
        next_line_indent = next_match[:indent] ? next_match[:indent].length : 0
        next unless (indent = next_line_indent - l1_indent) > 0
        
        
        l2_text   = l1_text.sub("{{#", "{{/")
        else_text = " " * l1_indent + "{{else}}"
        else_index = nil
        l2_index = lines[l1_index+1..-1].each_with_index.each do |line2, i2|
          else_index = i2 if line2.starts_with? else_text
          break i2 + l1_index+1 if line2.starts_with? l2_text
        end
    
        (l1_index+1..l2_index-1).each_with_index do |index, i|
          next if i == else_index
          mod_lines[index] = mod_lines[index][indent..-1]
        end
        
      end
    end
    mod_lines.join
  end
  
  class << self  
    attr_accessor :on_next_request
  end
  
  class Handler < Haml::Plugin
    
    class << self
    
      def call(template, options = {})
  
        view_match         = template.identifier.match(/^#{Rails.root.join('app', 'views')}[\/](?<view_path>[\/\w]+)[\/](?<view_name>\w+).html/)
        relative_view_path = view_match[:view_path]
        view_name          = view_match[:view_name]
        view_type          = get_view_type(template, relative_view_path, view_name)
        
        env = Rails.env.to_sym
        out = []
  
        #when in dev mode we can set this variable to true on each request (in the app controller)
        #and we scan for all changed partials (whether needed for the current view or not)
        #this is intended to ensure that all changes are picked up ready for deployment
        #even if the dev forgets to run the view that requires a changed partial
        #the rule is, render ANY page, and ALL partials should be re-compiled (if needed)
        #while for changed templates, you MUST run the view that you have changed
        if DryHamlHandlebars.on_next_request.values.any?
          DryHamlHandlebars.on_next_request.keys.each do |method|
            DryHamlHandlebars.on_next_request[method] = false
            case method
            when :compile_all_partials
              out += compile_and_load_all_partials
            else
              DryHamlHandlebars.send method
            end
          end
        end
  
        if [:layout, :ignored_partial].include? view_type
          out << super(template)
          return out.join("\n")
        end
  
        partial_name = [relative_view_path.gsub('/', '_'), view_name[1..-1]].join('_')
        rabl_path, template_path, compiled_template_path = generate_file_names(relative_view_path, view_name)
        if options[:force_handlebars_compile] or !File.exist?(compiled_template_path) or ( [:development, :test].include?(env) and ( File.mtime(compiled_template_path) < File.mtime(template.identifier) ) )
          source = template.source
          source = DryHamlHandlebars.dedent_hbs(source)
          template.instance_variable_set "@source", source
          rendered_haml = <<-RUBY
            rendered_haml = eval(%q( #{super(template)} )).html_safe
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
        
        out << runner.run
        out.join("\n")
          
      end
      
      def compile_and_load_all_partials
        partials = Dir.glob(Rails.root.join('app', 'views', '**', '_*.html.haml'))
        out = []
        partials.each do |fname|
          File.open(fname) do |file|
            source = file.read
            next unless source.starts_with?('-#handlebars_partial')
            source = DryHamlHandlebars.dedent_hbs(source)
            template = ActionView::Template.new(source, fname, nil, {:locals => ["__handlebars_partial"]})
            out << call(template, :force_handlebars_compile => true)
          end
        end
        out
      end
        
      def get_view_type(template, relative_view_path, view_name)
        
        #we have 4 types of view;
        # 1) layout           - always handled by haml, no hbs/js versions are generated
        # 2) template         - rendered as handlebars, we expect there to be html.haml AND .rabl for the JSON
        # 3) partial          - pulled into view by handlebars syntax {{>name}}
        # 4) ignored_partial  - a regular partial, it will be rendered by Haml, with no handlebars-related processing
        
        if relative_view_path == 'layouts'
          :layout
        elsif template.locals.include?("__handlebars_partial")
          :partial
        elsif view_name.starts_with? "_"
          :ignored_partial
        else
          :template
        end
              
      end
      
      def generate_file_names(relative_view_path, view_name)
        
        template_partial_path           = Rails.root.join( *%w(app assets templates)          << "#{relative_view_path}" )
        compiled_template_partial_path  = Rails.root.join( *%w(app assets compiled_templates) << "#{relative_view_path}" )
        
        rabl_path               = Rails.root.join( 'app', 'views', relative_view_path, "#{view_name}.rabl" )
        template_path           = File.join( template_partial_path, "#{view_name}.hbs" )
        compiled_template_path  = File.join( compiled_template_partial_path, "#{view_name}.js" )
        
        FileUtils.mkdir_p template_partial_path             unless File.directory? template_partial_path
        FileUtils.mkdir_p compiled_template_partial_path    unless File.directory? compiled_template_partial_path
        
        return rabl_path, template_path, compiled_template_path
        
      end
    
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
        out << get_hbs_context
        out << load_template
                  
      else #if we don't have any rendered haml (we're probably in production)
        
        out << get_hbs_context
        out << name_template
        
      end

      out << set_locale if defined? SimplesIdeias::I18n

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
    
    def get_hbs_context
      <<-RUBY
        hbs_context = HandlebarsAssets::Handlebars.send(:context)
      RUBY
    end
    
    def set_locale
      <<-RUBY
        hbs_context.eval("I18n.locale = '#{I18n.locale.to_s}'")
      RUBY
    end
    
    def load_template
      <<-RUBY
        File.open('#{@compiled_template_path}') do |file|
          hbs_context.eval(file.read, '#{@view_name}.js')
        end
      RUBY
    end
    
    def render_rabl
      
      if File.exist? @rabl_path
    
        rabl_handler  = ActionView::Template.handler_for_extension :rabl
        rabl_source   = File.read(@rabl_path)
        rabl_template = ActionView::Template.new(rabl_source, @rabl_path, rabl_handler, {:locals => @template.locals})
        rabl_call     = rabl_handler.call rabl_template

        <<-RUBY
          rabl_call_str = %q( #{rabl_call} )
          rendered_rabl = eval(rabl_call_str).html_safe
        RUBY
        
      else
        
        <<-RUBY
          rendered_rabl ||= '{}'.html_safe
        RUBY
        
      end
      
    end
    
    def set_gon_variable
      <<-'RUBY'
        Gon::Request.id  = request.object_id
        Gon::Request.env = request.env
        Gon.view_data  ||= JSON.parse(rendered_rabl)
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







