;;; Parameters

(defparameter old-reddit-handler
  (url-dispatching-handler
   'old-reddit-dispatcher
   (match-host "www.reddit.com")
   (lambda (url)
     (quri:copy-uri url :host "old.reddit.com"))))

;;; Init
(define-configuration buffer
    ((default-modes (append
                     '(auto-mode
                       force-https-mode
                       vi-normal-mode
                       blocker-mode)
                     %slot-default))
     (request-resource-hook
      (reduce #'hooks:add-hook
              (list old-reddit-handler)
              :initial-value %slot-default))))

(require :slynk)
(when (find-package :slynk)
  (nyxt::load-lisp "/home/emiller/.config/nyxt/slynk.lisp"))

;; (load-system :slynk)
;; (when (load-system :slynk)
;;     (define-command start-slynk (&optional (slynk-port *swank-port*))
;;         "Start a Slynk server that can be connected to, for instance, in
;; Emacs via SLY.

;; Warning: This allows Nyxt to be controlled remotely, that is, to
;; execute arbitrary code with the privileges of the user running Nyxt.
;; Make sure you understand the security risks associated with this
;; before running this command."
;;         (slynk:create-server :port slynk-port :dont-close t)
;;         (echo "Slynk server started at port ~a" slynk-port)))
