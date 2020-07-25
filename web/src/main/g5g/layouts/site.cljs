(ns g5g.layouts.site)

(defn navbar []
  [:nav.navbar.navbar-dark.bg-primary
   [:a.navbar-brand {:href "#"}
    "g5g"]
   [:div.collapse.navbar-collapse
    [:ul.navbar-nav
     [:li.nav-item.active
      [:a.nav-link {:href "#"}
       "Home"]]]]])

(defn site-layout [panel]
  [:<>
   [navbar]
   [panel]])
