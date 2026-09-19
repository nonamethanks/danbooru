# frozen_string_literal: true

# This component renders a form with an input for every attribute of a model, for use on a model's /search page. String
# and array attributes have a dropdown next to them to choose how the values are matched (e.g. wildcard, exact, regex).
#
# Attributes of associated models (e.g. an artist's tag) can be added with `extra_fields`, and params that don't
# correspond to a column can be added with `custom_fields`.
#
# @example
#   render AdvancedSearchComponent.new(
#     model: Artist,
#     url: artists_path,
#     params: search_params,
#     orders: [["Name", "name"]],
#     extra_fields: { tag: %i[post_count] },
#     custom_fields: [AdvancedSearchComponent::Field.new("URLs", :array, [["Matches any", %w[url_matches]], ["Matches all", %w[url_matches_all]]])],
#   )
class AdvancedSearchComponent < ApplicationComponent
  # A search input.
  #
  # @!attribute label [String] The label shown next to the input.
  # @!attribute type [Symbol] One of :string, :numeric, :datetime, :boolean or :array.
  # @!attribute params [Array<Array>] The `[label, path]` pairs of the search params the input can submit, where `path`
  #   is the list of keys under `search` (e.g. `%w[tag post_count]`). If there's more than one, the user picks which one
  #   to use with a dropdown.
  Field = Data.define(:label, :type, :params) do
    def key
      params.first.last.join("_")
    end
  end

  STRING_MATCH_TYPES = [["Wildcard", "ilike"], ["Exact", "eq"], ["Regex", "regex"]].freeze
  ARRAY_MATCH_TYPES = [["Matches any", "include_any_array"], ["Matches all", "include_all_array"]].freeze

  attr_reader :model, :url, :params, :orders, :extra_fields, :custom_fields

  # @param model [Class] The model being searched.
  # @param url [String] The URL the search form submits to.
  # @param params [Hash, ActionController::Parameters] The current search params, used to fill in the inputs.
  # @param orders [Array<Array<String>>] The `[label, value]` pairs for the order dropdown.
  # @param extra_fields [Hash<Symbol, Array<Symbol>>] Attributes of associations to add, e.g. `{ tag: %i[post_count] }`.
  # @param custom_fields [Array<Field>] Inputs for search params that don't correspond to a column.
  def initialize(model:, url:, params: {}, orders: [], extra_fields: {}, custom_fields: [])
    super
    @model = model
    @url = url
    @params = params.to_h.with_indifferent_access
    @orders = orders
    @extra_fields = extra_fields
    @custom_fields = custom_fields
  end

  # @return [Array<Field>] The inputs to render: the model's columns, then the extra fields, then the custom fields.
  def fields
    @fields ||= [
      *model.columns.map { |column| column_field(column) },
      *extra_fields.flat_map { |association, attributes| association_fields(association, attributes) },
      *custom_fields,
    ]
  end

  # @return [String] The name of the form input for a search param, e.g. `%w[tag post_count]` -> "search[tag][post_count]".
  def input_name(path)
    "search#{path.map { "[#{it}]" }.join}"
  end

  # @return [Array<String>] The path of the search param that is currently in use: the one present in the params, else the first.
  def selected_path(field)
    field.params.map(&:last).find { |path| params.dig(*path).present? } || field.params.first.last
  end

  # @return [String, Array<String>, nil] The current value of the field's input.
  def value(field)
    params.dig(*selected_path(field))
  end

  # @return [Array<String>] The current values of an array field's inputs, with one empty value if there are none.
  def array_values(field)
    Array.wrap(value(field)).flat_map(&:split).presence || [""]
  end

  # @return [Array<String>] The column and direction that are currently selected in the order dropdowns, e.g. "name_asc" -> ["name", "asc"].
  def selected_order
    column, direction = params[:order].to_s.match(/\A(.+?)(?:_(asc|desc))?\z/)&.captures
    [column || orders.first.last, direction || "desc"]
  end

  # @return [Hash<String, Hash>] The initial state of each array field's inputs, for Alpine.
  def array_state
    fields.select { it.type == :array }.to_h do |field|
      [field.key, { name: input_name(selected_path(field)), values: array_values(field) }]
    end
  end

  # @return [ActiveSupport::SafeBuffer] The <option> tags for the dropdown that picks which param a field submits.
  def match_options(field)
    helpers.options_for_select(field.params.map { |label, path| [label, input_name(path)] }, input_name(selected_path(field)))
  end

  private

  def association_fields(association, attributes)
    columns = model.reflect_on_association(association).klass.columns_hash
    attributes.map { |attribute| column_field(columns.fetch(attribute.to_s), [association.to_s]) }
  end

  def column_field(column, prefix = [])
    label = column.name.titleize.gsub(/\bId\b/, "ID")

    if column.array?
      Field.new(label, :array, match_types(column, ARRAY_MATCH_TYPES, prefix))
    elsif column.type.in?(%i[string text])
      Field.new(label, :string, match_types(column, STRING_MATCH_TYPES, prefix))
    elsif column.type == :boolean
      Field.new(label, :boolean, [[nil, [*prefix, column.name]]])
    elsif column.type.in?(%i[datetime date])
      Field.new(label, :datetime, [[nil, [*prefix, column.name]]])
    else
      Field.new(label, :numeric, [[nil, [*prefix, column.name]]])
    end
  end

  def match_types(column, types, prefix)
    types.map { |label, suffix| [label, [*prefix, "#{column.name}_#{suffix}"]] }
  end
end
