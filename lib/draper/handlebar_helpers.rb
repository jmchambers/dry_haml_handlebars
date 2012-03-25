module Draper
  module HandlebarHelpers
    
    module BlockBuffer
    
      class Store
        
        attr_accessor :store
        delegate :[], :[]=, :to => :store
        
        def initialize
          @store = Hash.new { |hash, key| hash[key] = Buffer.new }
        end

      end
      
      class Buffer
        
        attr_accessor :buffer
        delegate :[], :[]=, :empty?, :last, :inspect, :to => :buffer
        
        def initialize
          @buffer = []
        end
        
        def get_handle
          @buffer.length
        end
        
        def push(value)
          @buffer << value
          @buffer.length
        end
        
        def pop
          @buffer.pop
        end
        
        def return_handle(handle)
          raise "raise handle returned out of order!" unless handle == @buffer.length - 1
          @buffer.pop
        end
        
      end
    
    end
    
    CHAINED_CALL = /[a-z_]+\.+[a-z0-9_\.!?]/i
    
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    module ClassMethods
      
      def for_clientside(options = {})
        
        options.reverse_merge!(:new => false)
        
        obj = self.new
        
        #we'll create a spoof model to trick the rails form helpers
        #we're only changing this isntance's singleton model, so tha base model class is left intact
        
        model_class = obj.model_class
        spoof_model = model_class.new
        
        if options[:new] == false
          def spoof_model.id
            #make sure we report an id regardless of what datatype id is meant to be
            "#{self.class.name.underscore}_id".html_safe
          end
        end
        
        obj.instance_variable_set '@rendering_for_clientside', true #if we pass a model we must force this variable to be true otherwise we
        obj.instance_variable_set '@model',                    spoof_model
        obj.instance_variable_set '@handlebar_prefix',         options[:handlebar_prefix]
        obj
      end
      
    end
    
    # def test_list
      # [{a:1,b:2}, {'a' => 'foo', 'b' => 'bar'}, Struct.new(:a, :b).new(99,100)]
    # end
    
    def initialize(*args)
      super(*args) unless args.empty?
      self.init_haml_helpers
      @block_buffer = BlockBuffer::Store.new
      self
    end
    
    def model_name
      model_class.name.underscore
    end
    
    def [](method)
      
      method, html_safe = pre_process_method_call(method)
      calling_method    = caller[0][/`.*'/][1..-2]
      
      output =  case method
                when CHAINED_CALL
                  handle_chained_call(method, html_safe, calling_method)
                else
                  handle_single_call(method, html_safe, calling_method)
                end
      
      post_process_output(output, method, html_safe, calling_method)
      
    end
  
    def handle_chained_call(method, html_safe, calling_method)
        
      first_call, *other_calls = method.split('.')
      remaining_calls = other_calls.join('.')
      next_call = other_calls.first
      
      first_out = handle_single_call(first_call, html_safe, calling_method)
      
      if for_clientside?
        
        case first_out
        when ApplicationDecorator
          first_out[remaining_calls]
        when String, Symbol, Numeric
          first_out
        else  
          first_out = HandlebarWrapper #don't traverse hash keys, or eval objects, just insert {{method.chain}}
        end
        
      else
        
        if first_out == HandlebarWrapper
          raise "Your decorator methods should only return a HandlebarWrapper when rendering for clientside"
        elsif first_out.is_a? ApplicationDecorator
          first_out[remaining_calls]
        elsif first_out.is_a? Hash
          read_param_as_hash(method)
        else
          first_out.instance_eval remaining_calls
        end
        
      end
      
    end
      
    def handle_single_call(method, html_safe, calling_method)
      
      #puts "section items are #{@block_buffer[:section].inspect} for the call self[#{method}]"
  
      section_match = if @block_buffer[:section].present? and not for_clientside?
                        last_item = @block_buffer[:section].last
                        case last_item
                        when Hash
                          last_item[method] || last_item[method.to_sym]
                        else
                          last_item.send(method) if last_item.respond_to? method
                        end
                      end
        
      return section_match if section_match
      
      #if I call self['name'] from decorator method :name, we assume I mean the name method on the model this time (otherwise we get stack level too deep!)
      if self.respond_to? method and calling_method != method
        send method
      
      #must be a simple attribute request, but we have no model so we just return the mustache version
      elsif for_clientside? and model.respond_to? method
        return HandlebarWrapper
        
      
      #hit the model if we have one
      elsif model.respond_to? method
        model.send method
      
      #just wrap it and hope for the best...  
      elsif for_clientside?
        return HandlebarWrapper
        
      #or throw an error if we have no takers
      else
        raise NoMethodError, "no method called #{method}"
      end
           
    end
    
    def _if_with_else(param, &block)
      _if(param, true, &block)
    end
    
    def _if(param, has_else = false, &block)
      
      depth, base_indent, block_indent = indent_details(block)
      
      puts "_if#{param} depth = #{depth}"
      
      if for_clientside?
        
        if_str = "#{base_indent}{{#if #{lower_camelize_param(param)}}}\n#{block_indent}"
        end_str = "\n#{base_indent}{{/if}}"
        
        if has_else
          precede if_str, &block
        else
          surround if_str, end_str, &block
        end
        
      elsif param == false
        @block_buffer[:if][depth] = false
        return nil
        
      elsif param == true or self[param.to_s]
        @block_buffer[:if][depth] = true
        block.call
        return nil
        
      else
        @block_buffer[:if][depth] = false
        return nil
        
      end
      
    end
    
    def indent_details(block)
      depth = eval('haml_buffer.tabulation', block.binding)
      base_indent = "  " * depth
      block_indent = base_indent + "  "
      return depth, base_indent, block_indent
    end
    
    def _else(&block)
      
      depth, base_indent, block_indent = indent_details(block)
      puts "_else depth = #{depth}"
      
      if for_clientside?
        
        else_str = "#{base_indent}{{else}}\n#{block_indent}"
        end_str = "\n#{base_indent}{{/if}}"
        
        surround else_str, end_str, &block
        
      elsif @block_buffer[:if][depth] == false
        block.call
        return nil
        
      end
      
    end
    
    def _unless(param, &block)
      depth, base_indent, block_indent = indent_details(block)
      if for_clientside?
        surround(
          "{{#unless #{lower_camelize_param(param)}}}\n",
          "\n{{/unless}}",
          &block
        )
      elsif not self[param.to_s]
        block.call
        return nil
      end
    end
    
    def _section(param, &block)
      if for_clientside?
        surround(
          "{{##{lower_camelize_param(param)}}}\n",
          "\n{{/#{lower_camelize_param(param)}}}",
          &block
        )
      elsif (enum = self[param.to_s])
        handle = @block_buffer[:section].get_handle
        enum.each do |item|
          @block_buffer[:section][handle] = item
          block.call
        end
        @block_buffer[:section].return_handle(handle)
        return nil
      end
    end
    
    private
    
    class HandlebarWrapper; end
    
    def for_clientside?
      @rendering_for_clientside
    end
    
    def lower_camelize_param(param)
      param_parts = param.to_s.split('.')
      param_parts.insert(0, @handlebar_prefix) if @handlebar_prefix
      lower_camel_param = param_parts.map! {|part| part.camelize(:lower)}.join('.')
    end
    
    def handlebar_wrap(param, html_safe = false)
      lower_camel_param = lower_camelize_param(param)
      if html_safe
        "{{{#{lower_camel_param}}}}"
      else
        "{{#{lower_camel_param}}}"
      end
    end
    
    def read_param_as_hash(param)
      method, *keys = param.to_s.split('.')
      hash_or_value = send method
      if keys.empty?
        hash_or_value
      else
        keys.inject(hash_or_value){|h,k| h[k.to_sym]}
      end
    end
    
    def post_process_output(output, method, html_safe, calling_method)
      if output == HandlebarWrapper
        #method replied, effectively saying "I only return raw content, and as this is for the clientside, just wrap"
        handlebar_wrap(method, html_safe)
      elsif output.is_a?(String) or output.is_a?(Symbol)
        output = output.to_s
        if html_safe
          output.html_safe
        else
          output
        end
      elsif output.is_a?(Numeric) or output == true or output == false or output == nil
        output
      elsif %w(_section []).include? calling_method
        output
      else
        raise "a top level [] call must return a literal (string, symbol, numeric, nil or boolean), but I got #{output}, which is of class: #{output.class}"
      end
    end
    
    def pre_process_method_call(method)
      if method.is_a?(Array)
        method = method.first
        html_safe = true #only used if this is a simple attribute request on the model, those sending structured html handle this themselves
      else
        html_safe = false
      end
      
      unless method.is_a?(String) or method.is_a?(Symbol)
        raise ArgumentError, "method must be a string or symbol, but you sent #{method}, which is of class: #{method.class}"
      end
      
      method = method.to_s
      
      return method, html_safe
    end
     
  end
end