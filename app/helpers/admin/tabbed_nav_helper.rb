module Admin::TabbedNavHelper
  def tab_navigation_for(model, *extra_classes, &block)
    tabs = send("#{model.class.model_name.param_key}_tabs", model)
    tab_navigation(tabs, *extra_classes, &block)
  end

  def person_tabs(person)
    { "Details" => admin_person_path(person),
      "Translations" => admin_person_translations_path(person),
      "Historical accounts" => admin_person_historical_accounts_path(person) }
  end

  def topic_tabs(topic)
    {
      "Details" => url_for([:admin, topic]),
      "Features" => url_for([:admin, topic, :topical_event_featurings]),
    }
  end

  def corporate_information_page_tabs(page)
    {
      "Details" => polymorphic_path([:edit, :admin, page.organisation, page]),
      "Attachments" => admin_corporate_information_page_attachments_path(page.id),
    }
  end

  def policy_group_tabs(group)
    {
      "Group" => edit_admin_policy_group_path(group),
      "Attachments" => admin_policy_group_attachments_path(group),
    }
  end

  def tab_navigation(tabs, *extra_classes, &block)
    tabs = tab_navigation_header(tabs)
    tag.div(class: ["tabbable", *extra_classes]) do
      if block_given?
        tabs + tag.div(class: "tab-content", &block)
      else
        tabs
      end
    end
  end

  def tab_dropdown(label, menu_items)
    tag.li(class: "dropdown") do
      toggle = tag.a(class: "dropdown-toggle", 'data-toggle': "dropdown", href: "#") do
        "#{label} #{tag.b('', class: 'caret')}".html_safe
      end

      menu = tag.ul(class: "dropdown-menu") do
        menu_items
          .map { |sub_label, sub_content|
            tag.li(class: class_for_tab(sub_content)) do
              link_to(sub_label, sub_content)
            end
          }
          .join
          .html_safe
      end

      toggle + menu
    end
  end

  def tab_navigation_header(tabs)
    tag.ul(class: %w[nav nav-tabs add-bottom-margin]) do
      tabs.map { |label, content|
        if content.is_a?(Hash)
          tab_dropdown(label, content)
        else
          tag.li(link_to(label, content), class: class_for_tab(content))
        end
      }.join.html_safe
    end
  end

  def class_for_tab(url)
    request.path == url ? :active : nil
  end
end
