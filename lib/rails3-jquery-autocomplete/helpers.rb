module Rails3JQueryAutocomplete

  # Contains utility methods used by autocomplete
  module Helpers

    #
    # Returns a three keys hash actually used by the Autocomplete jQuery-ui
    # Can be overriden to show whatever you like
    #
    def json_for_autocomplete(items, method)
      items.collect {|item| {"id" => item.id, "label" => item.send(method), "value" => item.send(method)}}
    end

    # Returns parameter model_sym as a constant
    #
    #   get_object(:actor)
    #   # returns a Actor constant supposing it is already defined
    #
    def get_object(model_sym)
      object = model_sym.to_s.camelize.constantize
    end

    # Returns a symbol representing what implementation should be used to query
    # the database and raises *NotImplementedError* if ORM implementor can not be found
    def get_implementation(object) 
      ancestors_ary = object.ancestors.collect(&:to_s)
      if ancestors_ary.include?('ActiveRecord::Base')
        :activerecord
      elsif ancestors_ary.include?('Mongoid::Document')
        :mongoid
      else
        raise NotImplementedError
      end
    end

    #DEPRECATED
    def get_order(implementation, method, options)
      warn 'Rails3JQueryAutocomplete#get_order is has been DEPRECATED, please use #get_autocomplete_order instead'
      get_autocomplete_order(implementation, method, options)
    end

    # Returns the order parameter to be used in the query created by get_items
    def get_autocomplete_order(implementation, method, options)
      order = options[:order]

      case implementation
        when :mongoid then
          if order 
            order.split(',').collect do |fields|
              sfields = fields.split
              [sfields[0].downcase.to_sym, sfields[1].downcase.to_sym]
            end
          else
            [[method.to_sym, :asc]]
          end
        when :activerecord then 
          order || "#{method} ASC"
      end
    end

    # DEPRECATED
    def get_limit(options)
      warn 'Rails3JQueryAutocomplete#get_limit is has been DEPRECATED, please use #get_autocomplete_limit instead'
      get_autocomplete_limit(options)
    end

    # Returns a limit that will be used on the query
    def get_autocomplete_limit(options)
      options[:limit] ||= 10
    end

    # DEPRECATED
    def get_items(parameters)
      warn 'Rails3JQueryAutocomplete#get_items is has been DEPRECATED, you should use #get_autocomplete_items instead'
      get_autocomplete_items(parameters)
    end

    def get_autocomplete_scope(implementation, parameters)
      model = parameters[:model]
      options = parameters[:options]
      scope = parameters[:scope]
      filter_by = parameters[:filter_by]
      scope_rel = nil

      case implementation
        when :mongoid then
        when :activerecord then
          unless filter_by.blank?
            puts filter_by
            puts options[:filter_by]
            puts model.class.to_s + ' ' + model.scopes.keys.inspect
            puts scope
            if !options[:filter_by].blank? && model.scopes.has_key?(options[:filter_by])
              scope_rel = model.send(options[:filter_by], filter_by)
            elsif !scope.blank? && model.scopes.has_key?(scope.to_sym)
              scope_rel = model.send(scope.to_sym, filter_by)
            end
          end
      end
      scope_rel
    end

    #
    # Can be overriden to return or filter however you like
    # the objects to be shown by autocomplete
    #
    #   items = get_autocomplete_items(:model => get_object(object), :options => options, :term => term, :method => method) 
    #
    def get_autocomplete_items(parameters)
      model = parameters[:model]
      method = parameters[:method]
      options = parameters[:options]
      term = parameters[:term]
      is_full_search = options[:full]

      limit = get_autocomplete_limit(options)
      implementation = get_implementation(model)
      order = get_autocomplete_order(implementation, method, options)
      scope = get_autocomplete_scope(implementation, parameters)

      case implementation
        when :mongoid
          search = (is_full_search ? '.*' : '^') + term + '.*'
          items = model.where(method.to_sym => /#{search}/i).limit(limit).order_by(order)
        when :activerecord
          if scope.nil?
            items = model.where(["LOWER(#{method}) LIKE ?", "#{(is_full_search ? '%' : '')}#{term.downcase}%"]) \
            .limit(limit).order(order)
          else
            items = scope.where(["LOWER(#{model.table_name.to_s + '.' + method.to_s}) LIKE ?", "#{(is_full_search ? '%' : '')}#{term.downcase}%"]) \
            .limit(limit).order(model.table_name.to_s + '.' + order)
          end
      end
    end

  end
end
