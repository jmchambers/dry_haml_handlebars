module DryHamlHandlebars
  module ViewHelpers
    module ActionView
      
      # WARNING: content_for is ignored in caches. So you shouldn't use it
      # for elements that will be fragment cached.
      def handlebars_content_for(name, content = nil, flush = false)
        
        if content
          flush ? @view_flow.set(name, content) : @view_flow.append(name, content)
          nil
        else
          @view_flow.get(name)
        end
        
      end
      
      def handlebars_render(*args, &block)
        
        #we simply wrap render so that we can detect that 'handlebars_render' was the calling function
        #we do this by adding a local variable :handlebars_partial => true
        
        if args.first.is_a?(Hash)
          
          options = args.first
          options[:locals] ||= {}
          options[:locals].merge!(:__handlebars_partial => true)
          
        elsif args.last.is_a?(Hash)
          
          locals = args.last
          locals[:__handlebars_partial] = true
        
        else
  
          args << {:__handlebars_partial => true}
  
        end
        
        render(*args, &block)
        
      end
      
    end
  end
end