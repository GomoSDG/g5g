(ns g5g.core
  (:require [reagent.core :as r]
            [reagent.dom :as rdom]))

(defn main []
  [:h1 "Hello World!"])

(defn init []
  (rdom/render
   [main]
   (.getElementById js/document "app")))

