;;; eim-peep-dired.el --- Use EIMP and peep-dired as an image viewer

;; Copyright (C) 2017 Mahlon Collins

;; Author: Mahlon Collins <mac230@pitt.edu>
;; Keywords: files, convenience, dired, images
;; Package-Version: 0.1

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Original Commentary for peep-dired:

;; This is a minor mode that can be enabled from a dired buffer.
;; Once enabled it will show the file from point in the other window.
;; Moving to the other file within the dired buffer with <down>/<up> or
;; C-n/C-p will display a different file.
;; Hitting <SPC> will scroll the peeped file down, whereas
;; C-<SPC> and <backspace> will scroll it up.



;;; Commentary for eimp-peep-dired.el:

;; This is an alternative to peep-dired that modifies the
;; original package in the following ways:
;;
;; 1. It uses the Emacs Image Manipulation Package
;;    (https://www.emacswiki.org/emacs/EmacsImageManipulation)
;;    to automatically re-size images to fit the peep-dired
;;    window when peep-dired mode is enabled or on invoking
;;    peep-dired-snext-file or peep-dired-sprev-file.
;;
;; 2. It marks image buffers as unmodified so that the user
;;    is not prompted to save the changes caused by the
;;    re-sizing operation.
;;
;; 3. It kills peeped buffers on invoking peep-dired-snext-file
;;    or peep-dired-sprev-file.  This means peep-dired acts like
;;    a typical photo viewer application (rather than opening new
;;    files in separate windows) and keeps the buffer 
;;    list clean.
;;
;; 4. Several of the original key-bindings are altered.
;;
;; Note that the original peep-dired-next/prev-file
;; functionality for comparing two files in 
;; separate windows remains available, but is bound 
;; to M-p/M-n, instead of C-p/C-n, as in the original. 


;; REQUIREMENTS
;; 1. ImageMagick:
;;    http://www.imagemagick.org
;;
;; 2. Emacs Image Manipulation Package:
;;    https://www.emacswiki.org/emacs/EmacsImageManipulation
;;    See the 'talk' page for configuration help.


;; KNOWN LIMITATIONS
;; 1. The re-sizing operation relies on the mogrify function
;;    provided by ImageMagick.  This runs slowly for larger 
;;    images.  For this reason, the operation that marks
;;    the buffer as unmodified can sometimes finish before
;;    the re-sizing operation finishes.  In this instance,
;;    the user will be asked whether or not to save the
;;    changes to the image when disabling eim-peep-dired.  
;;    If you plan to work with many large images, 
;;    you can modify the timer settings in the source file.  
;;    The default is 0.250 sec.






;;; Code:

(require 'cl-macs)


(defvar eim-peep-dired-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "<down>")      'eim-peep-dired-snext-file)
    (define-key map (kbd "C-n")         'eim-peep-dired-snext-file)
    (define-key map (kbd "<up>")        'eim-peep-dired-sprev-file)
    (define-key map (kbd "C-p")         'eim-peep-dired-sprev-file)
    (define-key map (kbd "M-n")         'eim-peep-dired-next-file)
    (define-key map (kbd "M-p")         'eim-peep-dired-prev-file)
    (define-key map (kbd "<SPC>")       'eim-peep-dired-scroll-page-down)
    (define-key map (kbd "C-<SPC>")     'eim-peep-dired-scroll-page-up)
    (define-key map (kbd "<backspace>") 'eim-peep-dired-scroll-page-up)
    (define-key map (kbd "q")           'eim-peep-dired)
    map)
  "Keymap for `eim-peep-dired-mode'.")


(defvar eim-peep-dired-peeped-buffers ()
  "List with buffers of peeped files")


(defcustom eim-peep-dired-cleanup-on-disable t
  "Cleanup opened buffers when disabling the minor mode"
  :group 'eim-peep-dired
  :type 'boolean)


(defcustom eim-peep-dired-cleanup-eagerly nil
  "Cleanup opened buffers upon `peep-dired-next-file' & `peep-dired-prev-file'"
  :group 'eim-peep-dired
  :type 'boolean)


(defcustom eim-peep-dired-enable-on-directories t
  "When t it will enable the mode when visiting directories"
  :group 'eim-peep-dired
  :type 'boolean)


(defcustom eim-peep-dired-ignored-extensions
  '("mkv" "iso" "mp4" "svg")
  "Extensions to not try to open"
  :group 'eim-peep-dired
  :type 'list)


(defcustom eim-peep-dired-max-size (* 100 1024 1024)
  "Do to not try to open file exceeds this size"
  :group 'eim-peep-dired
  :type 'integer)


(defun eim-peep-dired-sprev-file ()  
  (interactive)
  (setq curr-dired (buffer-name))
  (dired-previous-line 1)
  (eim-peep-dired-cleanup)
  (eim-peep-dired-display-file-same-window)
  (dolist ($buf (buffer-list))
  (with-current-buffer $buf
    (when eimp-mode
     (eimp-dired-window-fit)))))


(defun eim-peep-dired-snext-file ()
  (interactive)
  (setq curr-dired (buffer-name))
  (dired-next-line 1)
  (eim-peep-dired-cleanup)
  (eim-peep-dired-display-file-same-window)
  (dolist ($buf (buffer-list))
  (with-current-buffer $buf
    (when eimp-mode
     (eimp-dired-window-fit)))))


(defun eim-peep-dired-next-file ()
  (interactive)
  (setq curr-dired (buffer-name))
  (dired-next-line 1)
  (setq new-buf (dired-copy-filename-as-kill))
  (eim-peep-dired-display-file-other-window)
  (switch-to-buffer-other-window next-buf)
  (eimp-fit-image-to-window-2)
  (run-with-timer 0.5 nil 'set-buffer-modified-p nil)
  (run-with-timer 0.5 nil 'switch-to-buffer-other-window curr-dired))


(defun eim-peep-dired-prev-file ()
  (interactive)
  (setq curr-dired (buffer-name))
  (dired-previous-line 1)
  (setq new-buf (dired-copy-filename-as-kill))
  (eim-peep-dired-display-file-other-window)
  (switch-to-buffer-other-window next-buf)
  (eimp-fit-image-to-window-2)
  (run-with-timer 0.5 nil 'set-buffer-modified-p nil)
  (run-with-timer 0.5 nil 'switch-to-buffer-other-window curr-dired))



(defun eim-peep-dired-kill-buffers-without-window ()
  "Will kill all peep buffers that are not displayed in any window"
  (interactive)
  (cl-loop for buffer in eim-peep-dired-peeped-buffers do
           (unless (get-buffer-window buffer t)
             (kill-buffer buffer))))


(defun eim-peep-dired-dir-buffer (entry-name)
  (with-current-buffer (or
                        (car (or (dired-buffers-for-dir entry-name) ()))
                        (dired-noselect entry-name))
    (when eim-peep-dired-enable-on-directories
      (setq eim-peep-dired 1)
      (run-hooks 'eim-peep-dired-hook))
    (current-buffer)))


(defun eim-peep-dired-display-file-other-window ()
  (let ((entry-name (dired-file-name-at-point)))
    (unless (or (member (file-name-extension entry-name)
                        eim-peep-dired-ignored-extensions)
                (> (nth 7 (file-attributes entry-name))
                   eim-peep-dired-max-size))
      (add-to-list 'eim-peep-dired-peeped-buffers
                   (window-buffer
                    (display-buffer
                     (if (file-directory-p entry-name)
                         (eim-peep-dired-dir-buffer entry-name)
                       (or
                        (find-buffer-visiting entry-name)
                        (find-file-noselect entry-name)))
                     t))))))


(defun eim-peep-dired-display-file-same-window ()  
  (let ((entry-name (dired-file-name-at-point)))
    (unless (or (member (file-name-extension entry-name)
                        eim-peep-dired-ignored-extensions)
                (> (nth 7 (file-attributes entry-name))
                   eim-peep-dired-max-size))
      (add-to-list 'eim-peep-dired-peeped-buffers
                   (window-buffer
                    (display-buffer
                     (if (file-directory-p entry-name)
                         (eim-peep-dired-dir-buffer entry-name)
                       (or
                        (find-buffer-visiting entry-name)
                        (find-file-noselect entry-name)))
                     '((display-buffer-use-some-window)
                      (inhibit-same-window . t))))))))


(defun eimp-dired-window-fit () 
;;1. switch to image window  
;;2. re-size to fit window  
;;3. mark as unmodified  
;;4. return to dired buffer
(interactive)
(dolist ($buf (buffer-list))
(with-current-buffer $buf
    (when eimp-mode
      (switch-to-buffer-other-window $buf)
      (eimp-fit-image-to-window-2))))
      (run-with-timer 0.5 nil 'no-eimp-mod)
      (run-with-timer 0.5 nil 'pop-to-buffer curr-dired))


(defun eimp-fit-image-to-window-2 ()
  (let* ((edges (window-inside-pixel-edges))
         (width (- (nth 2 edges) (nth 0 edges)))
         (height (- (nth 3 edges) (nth 1 edges))))
         (eimp-mogrify-image `("-resize" ,(concat 
         (format "%dx%d" width height))))))


(defun no-eimp-mod ()
(interactive)
(dolist ($buf (buffer-list))
(with-current-buffer $buf
    (when eimp-mode
      (switch-to-buffer $buf)
      (set-buffer-modified-p nil)))))


(defun eim-peep-dired-scroll-page-down ()
  (interactive)
  (scroll-other-window))


(defun eim-peep-dired-scroll-page-up ()
  (interactive)
  (scroll-other-window '-))


(defun eim-peep-dired-cleanup ()
  (mapc 'kill-buffer eim-peep-dired-peeped-buffers)
  (setq eim-peep-dired-peeped-buffers ()))


(defun eim-peep-dired-disable ()
  (let ((current-point (point)))
    (jump-to-register :eim_peep_dired_before)
    (when eim-peep-dired-cleanup-on-disable
      (mapc 'kill-buffer eim-peep-dired-peeped-buffers))
    (setq eim-peep-dired-peeped-buffers ())
    (goto-char current-point)))


(defun eim-peep-dired-enable ()
  (unless (string= major-mode "dired-mode")
    (error "Run it from dired buffer"))
  (setq curr-dired (buffer-name))
  (window-configuration-to-register :eim_peep_dired_before)
  (delete-other-windows)
  (eim-peep-dired-display-file-other-window)
  (dolist ($buf (buffer-list))
  (with-current-buffer $buf
    (when eimp-mode
     (eimp-dired-window-fit)))))


;;;###autoload
(define-minor-mode eim-peep-dired
  "Use EIMP and peep-dired as an image viewer."
  :init-value nil
  :lighter " eim-Peep"
  :keymap eim-peep-dired-mode-map

  (if eim-peep-dired
      (eim-peep-dired-enable)
    (eim-peep-dired-disable)))

(provide 'eim-peep-dired)

;;; eim-peep-dired.el ends here
