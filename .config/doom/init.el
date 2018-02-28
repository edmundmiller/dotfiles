;;; config/private/emiller/init.el -*- lexical-binding: t; -*-
(setq
    user-mail-address "Edmund.A.Miller@gmail.com"
    user-full-name "Edmund Miller"

     org-ellipsis " ▼ "

     )
;; Org Capture Templates
(setq org-capture-templates
    '(("a" "Appointment" entry
    (file  "~/Dropbox/orgfiles/gcal.org" "Appointments")
    "* TODO %?\n:PROPERTIES:\n\n:END:\nDEADLINE: %^T \n %i\n")

    ("n" "Note" entry
    (file+headline "~/Dropbox/orgfiles/i.org" "Notes")
    "** %?\n%T")

    ("l" "Link" entry
    (file+headline "~/Dropbox/orgfiles/links.org" "Links")
    "* %? %^L %^g \n%T" :prepend t)

    ("t" "To Do Item" entry
    (file+headline "~/Dropbox/orgfiles/i.org" "Unsorted")
    "*** TODO %?\n%T" :prepend t)

    ("j" "Lab Entry" entry
    (file+datetree "~/Dropbox/orgfiles/Lab_Notebook.org" "Lab Journal")
    "** %? %^g \n\n   Entered on %U\n  %i\n\n")

    ("d" "Lab To Do" entry
    (file+headline "~/Dropbox/orgfiles/Lab_Notebook.org" "To Do")
    "** TODO %?\n%T" :prepend t)))

;; Start in Insert
(add-hook 'org-capture-mode-hook 'evil-insert-state)

;; Bind capture to =C-c c=
(define-key global-map "\C-cc" 'org-capture)

;; Edit i.org
(defun emiller/visit-i-org ()
				(interactive)
				(find-file "~/Dropbox/orgfiles/i.org"))

		(global-set-key (kbd "C-c i") 'emiller/visit-i-org)

;; Set Bullets to OG
(setq org-bullets-bullet-list '("■" "◆" "▲" "▶"))

;; Make =C-c C-x C-s= change todo state
;; (defun emiller/mark-done-and-archive ()
;;         "Mark the state of an org-mode item as DONE and archive it."
;;        (interactive)
;;         (org-todo 'done)
;;         (org-archive-subtree))
;;
;; (define-key (kbd "C-c C-x C-s") 'emiller/mark-done-and-archive)

;; Change font
(setq doom-font (font-spec :family "Source Code Pro" :size 16))
