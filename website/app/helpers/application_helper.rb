module ApplicationHelper
  def active_nav(page)
    path = request.path
    active = ' class="active"'.html_safe
    active2 = 'active'.html_safe

    if path == '/'
      active if page == 'Home'
    elsif path == '/projects'
      active if page == 'Projects'
    elsif path == '/admin'
      active if page == 'Admin'
    elsif path == '/search'
      active if page == 'Search'
    end
  end

  def get_route
    route = request.env['PATH_INFO'].slice(request.env['PATH_INFO'].rindex('/') + 1..request.env['PATH_INFO'].length)
    route = route.slice(-5, 5) == '.html' ? route.slice(0, route.length - 5) : route
  end
end
