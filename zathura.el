;;; zathura.el --- Summary -*- lexical-binding: t -*-

;; Author: Aleksandr Kuzmin
;; Maintainer: Aleksandr Kuzmin
;; Version: 0.1
;; Package-Requires: ((emacs "24.3"))
;; Homepage: https://codeberg.org/treflip/zathura.el
;; Keywords: convenience

;; This file is not part of GNU Emacs

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;;; Commentary:
;; A set of simple commands that create hyperlinks to documents open in Zathura document viewer.

;;; Code:

(require 'dbus)


(defvar zathura-service-path "/org/pwmt/zathura")
(defvar zathura-service-iname "org.pwmt.zathura")


(defun zathura--get-procs ()
  (cl-remove-if-not (lambda (p) (string-match "zathura" p))
					(dbus-list-names :session)))


(defun zathura--dump-interface ()
  (dbus-introspect-get-interface :session
								 (elt (zathura--get-procs) 0)
								 zathura-service-path
								 zathura-service-iname))


(defun zathura--annotate-candidate (proc)
  ;; replace with (format ...) ?
  (propertize (concat "   page "
					  (format "%s" (dbus-get-property :session
														  proc
														  zathura-service-path
														  zathura-service-iname
														  "pagenumber"))
					  " "
					  (dbus-get-property :session
										 proc
										 zathura-service-path
										 zathura-service-iname
										 "filename"))
			  'face 'font-lock-comment-face))


(defun zathura--pick-process (procs)
  (completing-read "Select process: "
				   (lambda (str pred action)
					 (if (eq action 'metadata)
						 `(metadata
						   (annotation-function . zathura--annotate-candidate))
					   (complete-with-action action procs str pred)))))


(defun zathura-get-link-details ()
  (let* ((procs (zathura--get-procs))
		 (service)
		 (page)
		 (file))
	(cond ((= 1 (length procs))
		   (setq service (car procs)))
		  ((> (length procs) 1)
		   (setq service (zathura--pick-process procs)))
		  ((< (length procs) 1)
		   (error "Zathura is not running.")))
	(setq page (dbus-get-property :session service zathura-service-path
								  zathura-service-iname "pagenumber"))
	(setq file (dbus-get-property :session service zathura-service-path
								  zathura-service-iname "filename"))
	(cons file page)))


(defun zathura (file &optional page)
  "Call zathura with the given `file' and `page'."
  (if page
	  (call-process "zathura" nil 0 nil "-P" (format "%s" page) file)
	(call-process "zathura" nil 0 nil file)))


(defun zathura-insert-hy-link ()
  "Insert a link in the format used by Hyperbole to the current page from the chosen process of `zathura'"
  (interactive)
  (cl-destructuring-bind (file . page) (zathura-get-link-details)
	(insert (format "<zathura \"%s\" %s>" file page))))


(defun zathura-insert-org-elisp-link ()
  "Insert an elisp org-link to the current page from the chosen process of `zathura'"
  (interactive)
  (cl-destructuring-bind (file . page) (zathura-get-link-details)
	(insert (format "[[elisp:(zathura \"%s\" %s)][%s]]"
					file
					page
					(read-string "Description: ")))))


(provide 'zathura)

;;; zathura.el ends here
