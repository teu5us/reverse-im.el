;;; reverse-im.el --- Reverse mapping for keyboard layouts other than english. -*- lexical-binding: t -*-
;; Package-Requires: ((emacs "24.4"))
;; Keywords: input method
;; Homepage: https://github.com/a13/reverse-im.el

;;; Commentary:
;; Creates translation mappings for input-methods other than default english one,
;; so all (?) keybindings are usable while non-default system layout is active.
;; Example usage: (reverse-im-activate "russian-computer")

;; Main idea and some code taken from http://ru-emacs.livejournal.com/82428.html

;;; Code:

(require 'quail)
(require 'cl-extra)
(require 'cl-macs)

(defvar reverse-im--keymaps-alist
  `((t . ,function-key-map))
  "Alist of pairs input-method/translation keymap.")

(defun reverse-im--activate-key-def (keymap kd)
  "Add to KEYMAP KD key/definition list."
  (when kd
    (cl-destructuring-bind (key def) kd
      (define-key keymap key def))))

(defun reverse-im--translation-table (input-method)
  "Generate a translation table for INPUT-METHOD."
  (with-temp-buffer
    (activate-input-method input-method)
    (when (and current-input-method quail-keyboard-layout)
      (cl-mapcan
       (lambda (map)
         (mapcar
          (apply-partially #'reverse-im--key-def map)
          (list nil '(control) '(meta) '(control meta))))
       (cdr (quail-map))))))

(defun reverse-im--im-to-keymap (input-method)
  "Translation keymap for INPUT-METHOD."
  (let ((keymap (alist-get input-method reverse-im--keymaps-alist nil)))
    (or keymap
        (let ((new-keymap (make-sparse-keymap)))
          (mapc (apply-partially #'reverse-im--activate-key-def new-keymap)
                (reverse-im--translation-table input-method))
          (add-to-list 'reverse-im--keymaps-alist `(,input-method . ,new-keymap))
          new-keymap))))

(defun reverse-im--key-def (map mod)
  "Return a list of last two arguments for `define-key' for MAP with MOD modifier."
  (cl-destructuring-bind (keychar def) map
    (let ((from (quail-get-translation def (char-to-string keychar) 1)))
      (and (characterp from) (characterp keychar) (not (= from keychar))
           (list
            (vector (append mod (list from)))
            (vector (append mod (list keychar))))))))

(defun reverse-im-read-passwd-override-keymap (orig-fun &rest args)
  "Override `read-passwd' keymap."
  (let ((function-key-map nil)
        (read-passwd-map (let ((map read-passwd-map))
                           (set-keymap-parent map minibuffer-local-map)
                           (define-key map [return] #'exit-minibuffer)
                           (define-key map [backspace] #'delete-backward-char)
                           map)))
    (apply orig-fun args)))

(defun reverse-im-activate (input-method)
  "Activate the reverse mapping for INPUT-METHOD.
Example usage: (reverse-im-activate \"russian-computer\")"
  (setq function-key-map
        (make-composed-keymap
         (list
          (reverse-im--im-to-keymap input-method)
          function-key-map)))
  (advice-add 'read-passwd :around #'reverse-im-read-passwd-override-keymap))

(defun reverse-im-deactivate ()
  "Deactivate translated keymaps.
remove advice `reverse-im-read-passwd-override-keymap'."
  (setq function-key-map (alist-get t reverse-im--keymaps-alist nil))
  (set-keymap-parent local-function-key-map function-key-map)
  (advice-remove 'read-passwd  #'reverse-im-read-passwd-override-keymap))

(provide 'reverse-im)

;;; reverse-im.el ends here
