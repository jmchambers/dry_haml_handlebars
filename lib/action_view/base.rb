module ActionView
  class Base

    def handlebars_render(*args, &block)
      
      #we simply wrap render so that we can detect that 'handlebars_render' was the calling function
      #we do this by adding a local variable :handlebars_partial => true
      
      if args.first.is_a?(Hash)
        
        options = args.first
        options[:locals] ||= {}
        options[:locals].merge!(:handlebars_partial => true)
        
      elsif args.last.is_a?(Hash)
        
        locals = args.last
        locals[:handlebars_partial] = true
      
      else

        args << {:handlebars_partial => true}

      end
      
      render(*args, &block)
      
    end

  end
end