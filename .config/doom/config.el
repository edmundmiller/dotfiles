;;; config.el --- description -*- lexical-binding: t; -*-
;; Edit Server
(def-package! edit-server
		:config
				(edit-server-start))

;; Solidity
(def-package! solidity-mode
  :mode "\\.sol$"
  :config
    (setq solidity-solc-path "/home/emiller/node/lib/node_modules/solc/solcjs")
    (setq solidity-solium-path "/home/emiller/node/lib/node_modules/solium/bin/solium")

    (setq solidity-flycheck-solc-checker-active t)
    (setq solidity-flycheck-solium-checker-active t)

    (setq flycheck-solidity-solc-addstd-contracts t)
    (setq flycheck-solidity-solium-soliumrcfile "~/.soliumrc.json")

    (setq solidity-comment-style 'slash))

(def-package! company-solidity
  :when (featurep! :completion company)
  :after solidity-mode
  :config
  (add-hook 'solidity-mode-hook
    (lambda ()
    (set (make-local-variable 'company-backends)
        (append '((company-solidity company-capf company-dabbrev-code))
        company-backends)))))

;; app/email
(after! mu4e
  (setq mu4e-bookmarks
        `(("\\\\Inbox" "Inbox" ?i)
          ("\\\\Draft" "Drafts" ?d)
          ("flag:unread AND \\\\Inbox" "Unread messages" ?u)
          ("flag:flagged" "Starred messages" ?s)
          ("date:today..now" "Today's messages" ?t)
          ("date:7d..now" "Last 7 days" ?w)
          ("mime:image/*" "Messages with images" ?p)))

  (setq smtpmail-stream-type 'starttls
        smtpmail-default-smtp-server "smtp.gmail.com"
        smtpmail-smtp-server "smtp.gmail.com"
        smtpmail-smtp-service 587)

  (set! :email "gmail.com"
    '((mu4e-sent-folder       . "/gmail.com/Sent Mail")
      (mu4e-drafts-folder     . "/gmail.com/Drafts")
      (mu4e-trash-folder      . "/gmail.com/Trash")
      (mu4e-refile-folder     . "/gmail.com/All Mail")
      (smtpmail-smtp-user     . "edmund")
      (user-mail-address      . "edmund.a.miller@gmail.com"))) ;; an evil-esque keybinding scheme for mu4e
  (setq mu4e-view-mode-map (make-sparse-keymap)
        ;; mu4e-compose-mode-map (make-sparse-keymap)
        mu4e-headers-mode-map (make-sparse-keymap)
        mu4e-main-mode-map (make-sparse-keymap))

  (map! (:map (mu4e-main-mode-map mu4e-view-mode-map)
          :leader
          :n "," #'mu4e-context-switch
          :n "." #'mu4e-headers-search-bookmark
          :n ">" #'mu4e-headers-search-bookmark-edit
          :n "/" #'mu4e~headers-jump-to-maildir)

        (:map (mu4e-headers-mode-map mu4e-view-mode-map)
          :localleader
          :n "f" #'mu4e-compose-forward
          :n "r" #'mu4e-compose-reply
          :n "c" #'mu4e-compose-new
          :n "e" #'mu4e-compose-edit)

        (:map mu4e-main-mode-map
          :n "q"   #'mu4e-quit
          :n "u"   #'mu4e-update-index
          :n "U"   #'mu4e-update-mail-and-index
          :n "J"   #'mu4e~headers-jump-to-maildir
          :n "c"   #'+email/compose
          :n "b"   #'mu4e-headers-search-bookmark)

        (:map mu4e-headers-mode-map
          :n "q"   #'mu4e~headers-quit-buffer
          :n "r"   #'mu4e-compose-reply
          :n "c"   #'mu4e-compose-edit
          :n "s"   #'mu4e-headers-search-edit
          :n "S"   #'mu4e-headers-search-narrow
          :n "RET" #'mu4e-headers-view-message
          :n "u"   #'mu4e-headers-mark-for-unmark
          :n "U"   #'mu4e-mark-unmark-all
          :n "v"   #'evil-visual-line
          :nv "d"  #'+email/mark
          :nv "="  #'+email/mark
          :nv "-"  #'+email/mark
          :nv "+"  #'+email/mark
          :nv "!"  #'+email/mark
          :nv "?"  #'+email/mark
          :nv "r"  #'+email/mark
          :nv "m"  #'+email/mark
          :n "x"   #'mu4e-mark-execute-all

          :n "]]"  #'mu4e-headers-next-unread
          :n "[["  #'mu4e-headers-prev-unread

          (:localleader
            :n "s" 'mu4e-headers-change-sorting
            :n "t" 'mu4e-headers-toggle-threading
            :n "r" 'mu4e-headers-toggle-include-related

            :n "%" #'mu4e-headers-mark-pattern
            :n "t" #'mu4e-headers-mark-subthread
            :n "T" #'mu4e-headers-mark-thread))

        (:map mu4e-view-mode-map
          :n "q" #'mu4e~view-quit-buffer
          :n "r" #'mu4e-compose-reply
          :n "c" #'mu4e-compose-edit
          :n "o" #'ace-link-mu4e

          :n "<M-Left>"  #'mu4e-view-headers-prev
          :n "<M-Right>" #'mu4e-view-headers-next
          :n "[m" #'mu4e-view-headers-prev
          :n "]m" #'mu4e-view-headers-next
          :n "[u" #'mu4e-view-headers-prev-unread
          :n "]u" #'mu4e-view-headers-next-unread

          (:localleader
            :n "%" #'mu4e-view-mark-pattern
            :n "t" #'mu4e-view-mark-subthread
            :n "T" #'mu4e-view-mark-thread

            :n "d" #'mu4e-view-mark-for-trash
            :n "r" #'mu4e-view-mark-for-refile
            :n "m" #'mu4e-view-mark-for-move))

        (:map mu4e~update-mail-mode-map
            :n "q" #'mu4e-interrupt-update-mail)))

(provide 'config)
;;; config.el ends here
