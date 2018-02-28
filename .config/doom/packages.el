;;; packages.el --- description -*- lexical-binding: t; -*-

(package! solidity-mode)
(when (featurep! :completion company)
  (package! company-solidity))

(package! edit-server)

(provide 'packages)
;;; packages.el ends here
