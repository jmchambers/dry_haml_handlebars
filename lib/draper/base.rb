module Draper
  class Base
    
    #this monkey patch ensures that decorating associations works when we are using the decorator without a specific model i.e. when rendering for clientside use
    
    #note this only removes the custom versions of these from Draper::Base
    #we still have the standard ruby versions
    remove_method :respond_to?
    remove_method :method_missing
    
    def self.decorates_association(association_symbol, options = {})
      
      define_method(association_symbol) do
        
        if for_clientside?
        
          klass = model_class.reflect_on_association(association_symbol).klass
          "#{klass}Decorator".constantize.for_clientside(:handlebar_prefix => association_symbol.to_s)
        
        else
          
          #ORIGINAL CODE
        
          orig_association = model.send(association_symbol)
  
          return orig_association if orig_association.nil?
  
          return options[:with].decorate(orig_association) if options[:with]
  
          if options[:polymorphic]
            klass = orig_association.class
          elsif model.class.respond_to?(:reflect_on_association) && model.class.reflect_on_association(association_symbol)
            klass = model.class.reflect_on_association(association_symbol).klass
          elsif orig_association.respond_to?(:first)
            klass = orig_association.first.class
          else
            klass = orig_association.class
          end
          "#{klass}Decorator".constantize.decorate(orig_association, options)
        
        end

      end
      
    end
      
    #this monkey patch stops Draper from creating new methods dynamically when a request for an attribute needs passing through to the model
    #they were creating the method to avoid a lookup on the next call, but for reasons I don't understand, this was causing problems
    #when a user signed in or out i.e. the old method was somehow broken - this only appears to happen when I use handlebars.js!
    #anyway - my workaround is to just simply ask the model whether it can respond each time

    def method_missing(method, *args, &block)
      super unless allow?(method)

      if model.respond_to?(method)
        model.send method, *args, &block
      else
        super
      end

    rescue NoMethodError => no_method_error
      super if no_method_error.name == method
      raise no_method_error
    end

  end
  
end
