module ActionController
  class Base
    
    def render_extra_content_for(*args)
      options = args.extract_options!
      args.each do |identifier|
        name, path = get_content_for_name_and_path(identifier, options)
        DryHamlHandlebars.content_cache.add_item(name, path)
      end
      
    end
      
    private
    
    def get_content_for_name_and_path(identifier, options)
      
      case identifier
      when Symbol
        
        name = identifier
        
        possible_folders = [
          Rails.root.join( *%w[app views] << params[:controller] ).to_s,
          Rails.root.join( *%w[app views application] ).to_s
        ]
        
        if folders = options[:prepend_search_folders]
          possible_folders = folders + possible_folders
        end
        
        if folders = options[:append_search_folders]
          possible_folders += folders
        end
        
        possible_filenames = [
          "#{params[:action]}_#{name}.html.haml",
          "#{name}.html.haml",
          "#{params[:action]}_content_for_#{name}.html.haml",
          "content_for_#{name}.html.haml"
        ]
        
        possible_paths = []
        
        possible_folders.each do |folder|
          possible_filenames.each do |fname|
            possible_paths << File.join( folder, fname )
          end
        end
        
        path = possible_paths.find { |p| File.exist?(p) }
        raise "couldn't find any of the following expected files:\n#{possible_paths.join("\n")}" if path.nil?
        
      when Array
        
        path = Rails.root.join( *%w[app views] << "#{identifier.last}.html.haml" ).to_s
        name = identifier.first.to_sym
      
      when String
        
        path = Rails.root.join( *%w[app views] << "#{identifier}.html.haml" ).to_s
        name_match = identifier.match(/.*content_for_(?<name>\w*)/)
        if name_match
          name = name_match[:name].to_sym
        else
          name = identifier
        end
        
      else
        raise ArgumentError, "expected identifier to be a Array, Symbol or String, but got #{identifier}"
      end
      
      raise "the file #{path} does not exist" unless File.exist?(path)

      return name, path
    
    end

    
  end
end