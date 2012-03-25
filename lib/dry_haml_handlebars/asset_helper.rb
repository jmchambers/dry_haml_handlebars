module DryHamlHandlebars
  
  module AssetHelper
    
    require 'handlebars'
    
    def template_include_tag(*args)
      hbs_context = ::Handlebars::Context.new
      current_env = Rails.env.to_s
      sources, locals = parse_args(args)

      sources.collect do |source|
        
        full_path = resolve_partial_path(source).to_s
        markup = File.open(full_path, "rb").read.html_safe
        options = Haml::Template.options.dup
        options[:filename] = full_path
        
        begin
          decorator_class = "#{@model_class_name}Decorator".constantize
          decorator = decorator_class.for_clientside 
          locals.reverse_merge!(@model_class_name.underscore => decorator)
        rescue NameError
          decorator_class = nil
        end

        locals.each do |k,v|
          #ensure we can handle, for example, both @article[] and article[] in the haml
          self.instance_variable_set "@#{k}", v
        end
      
       
        template = Haml::Engine.new(markup, options).render(self, locals)
        
        compiled_template = hbs_context.handlebars.precompile template
        compiled_template_tag = content_tag :script, template_loader_script(compiled_template).html_safe, :type => "text/javascript", :id => "#{@id_array.join('-')}-compiled-template"
        
        if current_env == 'development'
          template_tag = content_tag :script, template.html_safe, :type => "text/x-handlebars-template", :id => "#{@id_array.join('-')}-template"
          [template_tag, compiled_template_tag].join("\n").html_safe
        else
          compiled_template_tag
        end

      end.join("\n").html_safe
    end
    
    private
    
    def parse_args(args)
      locals = if args.length > 1 and args.last.is_a? Hash
        args.pop
      else
        {}
      end
      return args, locals
    end
    
    def template_loader_script(compiled_template)
      app_name = Rails.application.class.to_s.split("::").first
      <<-JAVASCRIPT
        (function() {
          window.#{app_name}    || (window.#{app_name} = {});
          #{app_name}.Templates || (#{app_name}.Templates = {});
          #{app_name}.Templates["#{@id_array.join('/')}"] = Handlebars.template(#{compiled_template});
        }).call(this);
      JAVASCRIPT
    end

    def is_absolute_path?(source)
      source.to_s =~ /^\//
    end

    def template_name(source)
      if is_absolute_path?(source)
        source.to_s.split('/').last
      else
        source
      end
    end

    def resolve_partial_path(source)
      if is_absolute_path?(source)
        segments = source.to_s.split('/')[1..-1]
        @view_name = segments.pop
        @id_array = segments.dup << @view_name.sub('_', '')
        @model_class_name = segments.first.singularize.camelize 
        Rails.root.join('app/views', *segments, "#{@view_name}.html.haml")
      end
    end
  end
end
