(ns g5g.core
  (:require [reagent.core :as r]
            [reagent.dom :as rdom]
            [g5g.layouts.site :refer [site-layout]]
            [g5g.routes :as routes :refer [hook-browser-navigation!]]
            [g5g.views :as views]
            [re-frame.core :as re-frame]))

(re-frame/reg-event-db
 :initialize-db
 (fn [_ _]
   {:active-panel :home
    :panels views/panels}))

(defn render-active-panel []
  (let [active-panel @(re-frame/subscribe [:active-panel])]
    (rdom/render
     [site-layout active-panel]
     (.getElementById js/document "app"))))

(defn init []
  (re-frame/dispatch-sync [:initialize-db])
  (hook-browser-navigation!)
  (render-active-panel))
