module ActionController
  class Base
    
    def render_extra_content_for(*args)
      
      args.each do |identifier|
        name, path = get_content_for_name_and_path(identifier)
        DryHamlHandlebars.content_cache.add_item(name, path)
      end
      
    end
      
    private
    
    def get_content_for_name_and_path(identifier)
      
      case identifier
      when Symbol
        
        name = identifier
        view_folder = Rails.root.join( *%w[app views] << params[:controller] << params[:action] ).to_s
        possible_filenames = [
          "#{params[:action]}_content_for_#{name}",
          "content_for_#{name}"
        ]
        possible_paths = possible_filenames.map { |fname| Rails.root.join( *%w[app views] << params[:controller] << "#{fname}.html.haml" ).to_s }
        path = possible_paths.find { |p| File.exist?(p) }
        raise "couldn't find any of the following expected files:\n#{possible_paths.join("\n")}" if path.nil?
        
      when String
        
        path = Rails.root.join( *%w[app views] << "#{identifier}.html.haml" ).to_s
        raise "the file #{path} does not exist" unless File.exist?(path)
        name_match = identifier.match(/.*content_for_(?<name>\w*)/)
        if name_match
          name = name_match[:name].to_sym
        else
          raise "couldn't extract a content_for name from #{identifier}"
        end
        
      else
        raise ArgumentError, "expected identifier to be a Symbol or String, but got #{identifier}"
      end
      
      return name, path
    
    end

    
  end
end