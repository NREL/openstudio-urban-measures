module ApplicationHelper
	def active_nav(page)
    path = request.path
    active = ' class="active"'.html_safe
    active2 = 'active'.html_safe

    if path == '/'
      active if page == 'Home'
    elsif path == '/buildings'
      active if page == 'Buildings'
    elsif path == '/taxlots'
      active if page == 'Taxlots'
    elsif path == '/regions'
      active if page == 'Regions'
    elsif path == '/district_systems'
      active if page == 'District Systems'
    elsif path == '/admin'
      active if page == 'Admin'
    elsif path == '/search'
      active if page == 'Search'
    end
  end
end
