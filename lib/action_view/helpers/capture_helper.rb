include ActionView::Helpers

module ActionView
  module Helpers
    module CaptureHelper
      
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
      
    end
  end
end