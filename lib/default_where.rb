require 'default_where/not'
require 'default_where/range'
require 'default_where/like'
require 'default_where/order'
require 'default_where/or'

module DefaultWhere
  include DefaultWhere::Not
  include DefaultWhere::Range
  include DefaultWhere::Order
  include DefaultWhere::Like
  include DefualtWhere::Or

  REJECT = ['', nil]
  STRIP = true

  def default_where(params = {}, options = {})
    return all if params.blank?

    params = params.to_h
    params.stringify_keys!
    params, refs, tables = params_with_table(params, options)

    or_params = filter_or(params)
    range_params = filter_range(params)
    order_params = filter_order(params)
    not_params = filter_not(params)
    like_params = filter_like(params)

    equal_params = params.except!(*range_params.keys, *order_params.keys, *not_params.keys, *like_params.keys)

    includes(refs).where(equal_params).references(tables)
      .not_scope(not_params)
      .like_scope(like_params)
      .range_scope(range_params)
      .order_scope(order_params)
  end

  def params_with_table(params = {}, options = {})
    if options.has_key?(:reject)
      default_reject = Array(options[:reject])
    elsif options.has_key?(:allow)
      default_reject = REJECT - Array(options[:allow])
    else
      default_reject = REJECT
    end

    unless options.has_key? :strip
      options[:strip] = STRIP
    end

    refs = []
    tables = []
    final_params = {}

    params.each do |key, value|
      value = value.strip if value.is_a?(String) && options[:strip]
      next if default_reject.include?(value)

      if key =~ /\./
        _table, _column = key.split('.')
        _real_column = _column.split('-').first
        _ref = reflections[_table]
        if _ref && _ref.klass.column_names.include?(_real_column)
          _real_table = _ref.table_name
        elsif connection.data_sources.include?(_table) && connection.column_exists?(_table, _real_column)
          _real_table = _table
          keys = reflections.select { |_, v| !v.polymorphic? && v.table_name == _table }.keys
          if keys && keys.size == 1
            _ref = keys.first.to_sym
          else
            raise 'please use reflection name!'
          end
        else
          return
        end
        final_params["#{_real_table}.#{_real_column}"] = value
      else
        _real_column = key.split('-').first
        return [] unless column_names.include?(_real_column)
        final_params["#{key}"] = value
      end
    end

    [final_params, refs, tables]
  end

end

ActiveSupport.on_load :active_record do
  extend DefaultWhere
end