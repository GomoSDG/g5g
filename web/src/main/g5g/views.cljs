(ns g5g.views
  (:require [g5g.panels.home :as home]
            [re-frame.core :as re-frame]))

(def panels {:home #'home/home})

(re-frame/reg-event-db
 :set-active-panel
 (fn [db [_ panel]]
   (assoc db :active-pane panel)))

(re-frame/reg-sub
 :active-panel
 (fn [db]
   (let [panels          (:panels db)
         active-panel    (:active-panel db)
         active-panel-fn (panels active-panel)]
     active-panel-fn)))
