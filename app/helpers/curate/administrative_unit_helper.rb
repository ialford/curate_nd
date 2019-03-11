module Curate::AdministrativeUnitHelper
  def administrative_unit_option_listing(curation_concern)
    select_administrative_unit_ids = []
    processed_administrative_unit_ids = []

    administrative_units = Array.wrap(curation_concern.administrative_unit)

    administrative_units.each do |administrative_unit|
      select_administrative_unit_ids << administrative_unit
    end

    options = ''

    roots = ControlledVocabularyService.active_hierarchical_roots(name: 'administrative_units')

    roots.each do |root|
      root.children.each do |administrative_unit|
        processed_administrative_unit_ids << administrative_unit.selectable_id
        options << "<optgroup label=\"#{optgroup_label_for(administrative_unit)}\">".html_safe

        if administrative_unit.selectable?
          options << administrative_unit_options_from_collection_for_select_with_attributes(
            [administrative_unit], 'selectable_id', 'selectable_label','indent', 'children', select_administrative_unit_ids
          )
        end

        if administrative_unit.children.present?
          selectable_children = administrative_unit.children.reject {|n| !n.selectable?}
          not_selectable_children = administrative_unit.children.reject {|n| n.selectable?}
          options << administrative_unit_options_from_collection_for_select_with_attributes(
            selectable_children, 'selectable_id', 'selectable_label', 'indent', 'children', select_administrative_unit_ids
          )
          options << administrative_units_select_options_html(
            not_selectable_children, processed_administrative_unit_ids, select_administrative_unit_ids
          )
        end
        options << '</optgroup>'.html_safe
      end
    end
    return options
  end

  private

  # University of Notre Dame is a three-level hierarchy
  # Non-UND Administrative Units MUST be 2-level hierarchies
  def optgroup_label_for(administrative_unit)
    if administrative_unit.root_slug == "University of Notre Dame"
      administrative_unit.selectable_label
    else
      administrative_unit.root_slug
    end
  end

  def administrative_units_select_options_html(administrative_units, processed_administrative_unit_ids = [], selected_list)
    administrative_units.map do |administrative_unit|
      if administrative_unit.selectable?
        content_tag(
          :option,
          value: administrative_unit.selectable_id,
          selected: administrative_unit_is_selected?( administrative_unit, selected_list),
          data: { indent: 4 }
        ) { administrative_unit.selectable_label } + administrative_units_select_options_html(
          administrative_unit.children, processed_administrative_unit_ids
        )
      else
        content_tag(
          :option,
          value: administrative_unit.selectable_id,
          disabled: true,
          data:{ indent: 2, class: 'bold-row' }
        ) { administrative_unit.selectable_label } + administrative_units_select_options_html(
          administrative_unit.children, processed_administrative_unit_ids, selected_list
        )
      end
    end.join.html_safe
  end

  def administrative_unit_options_from_collection_for_select_with_attributes(collection, value_method, text_method, attr_name, attr_field, selected = nil)
    options = collection.map do |element|
      [ element.send(text_method), element.send(value_method), "data-" + attr_name => element.send(attr_field).size ]
    end

    selected, disabled = extract_selected_and_disabled(selected)
    select_deselect = {}
    select_deselect[:selected] = extract_values_from_collection(collection, value_method, selected)
    select_deselect[:disabled] = extract_values_from_collection(collection, value_method, disabled)

    options_for_select(options, select_deselect)
  end

  def administrative_unit_is_selected?(administrative_unit,selected_list)
    selected_list.include?(administrative_unit.id)
  end
end
