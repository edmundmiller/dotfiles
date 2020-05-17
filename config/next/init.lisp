(in-package :next-user)

(defclass my-buffer (buffer)
  ((default-modes :initform
     (cons 'vi-normal-mode (get-default 'buffer 'default-modes)))))

(setf *buffer-class* 'my-buffer)
