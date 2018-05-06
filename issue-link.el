;;; issue-link.el --- Get the link to JIRA/Tracker/GitHub issues -*- lexical-binding: t -*-

;; Copyright (C) 2018 Skye Shaw
;; Author: Skye Shaw <skye.shaw@gmail.com>
;; Version: 0.0.1
;; Keywords: git, vc, jira, github, bitbucket, gitlab, convenience
;; URL: http://github.com/sshaw/issue-link
;; Package-Requires: ((cl-lib "0.6.1") (button-lock "1.0.2"))

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Get the link to JIRA/Tracker/GitHub etc... bugs, features & issues.
;; Turn their IDs into buttons.
;;
;; `issue-link-mode' will turn matching issue IDs into buttons linking
;; to the issue.
;;
;; `issue-link' is an interactive function that will get the link for an issue, or the
;; issue associated with the current branch.

(require 'cl-lib)
(require 'url-parse)
(require 'button-lock)

;; We don't want button-lock showing in the mode line
(setq button-lock-mode-lighter nil)

(defgroup issue-link nil
  "Get the link to JIRA/Tracker/GitHub etc... bugs, features & issues.
Turn their IDs into buttons."
  :prefix "issue-link-"
  :link '(url-link :tag "Report a Bug" "https://github.com/sshaw/issue-link/issues")
  :link '(url-link :tag "Homepage" "https://github.com/sshaw/issue-link")
  :group 'convenience)

(defcustom issue-link-issue-regexp "#[0-9]+\\b"
  "Regexp to match issue numbers in buffers.
In most cases you should set `issue-link-issue-alist'."
  :type 'regexp
  :group 'issue-link)

(defcustom issue-link-issue-alist nil
  "Alist of issue ID regexps and URL templates.
Each element looks like (REGEXP TEMPLATE) where REGEXP is used to
match an issue ID and TEMPLATE is a URL containing `%s', which will be
replaced with the issue ID matched by REGEXP."
  :type '(alist :key-type regexp :value-type string)
  :group 'issue-link)

(defcustom issue-link-mouse-binding 'mouse-1
  "Mouse binding used to open an issue button's link."
  :type 'key-sequence
  :group 'issue-link)

(defcustom issue-link-keyboard-binding "RET"
  "Keyboard binding used to open an issue button's link."
  :type 'key-sequence
  :group 'issue-link)

(defcustom issue-link-kill t
  "If non-nil add link to `kill-ring' when calling `issue-link'."
  :type 'boolean
  :group 'issue-link)

(defcustom issue-link-open-in-browser nil
  "If non-nil open link in browser via `browse-url' when calling `issue-link'."
  :type 'boolean
  :group 'issue-link)

(defun issue-link--exec (&rest args)
  (ignore-errors (apply 'process-lines `("git" ,@(when args args)))))

(defun issue-link--get-config (name)
  (car (issue-link--exec "config" "--get" name)))

(defun issue-link--current-branch ()
  (car (issue-link--exec "symbolic-ref" "--short" "HEAD")))

(defun issue-link--remote-url ()
  (let ((branch (issue-link--current-branch)))
    (when branch
      (issue-link--get-config (format "remote.%s.url"
                                      ;; FIXME: branch.master.pushremote. When/how is this set?
                                      (issue-link--get-config (format "branch.%s.remote" branch)))))))

(defun issue-link--build-link-error (issue-id)
  (user-error "Unable to build an issue link for id %s" (or issue-id "(unknown)")))

(defun issue-link--url-for-custom-regexp (issue-id)
  (let ((url (cadr (cl-find issue-id
                            issue-link-issue-alist
                            :test '(lambda (id pair) (string-match (car pair) id))))))
    (when url
      (format url issue-id))))

(defun issue-link--url-for-repo (issue-id)
  (let ((url (issue-link--remote-url)))
    (when (and url
               (setq url (issue-link--parse-remote url))
               (string-match "\\([^/]+/[^/]+\\)"
                             (replace-regexp-in-string ".git\\>" "" (url-filename url))))

      (format "https://%s/%s/issues/%s"
              (url-host url)
              (match-string 1 (url-filename url))
              issue-id))))

;; TODO: Look at commit message for: "[FIXES XXX]"?
(defun issue-link--extract-branch-id ()
  "Extract the issue associated with the current branch."
  (let ((branch (issue-link--current-branch)))
    (when branch
      (catch 'found
        (dolist (cfg issue-link-issue-alist)
          (let ((regex (concat "\\(^" (car cfg) "\\|" (car cfg) "$\\)")))
            (when (string-match regex branch)
              (throw 'found (match-string 1 branch)))))))))

(defun issue-link--button-click ()
  ;; button-lock callback requires an interactive function
  (interactive)
  (let* ((points (button-lock-find-extent))
         (issue-id (replace-regexp-in-string "^#" "" (buffer-substring-no-properties (car points) (cdr points))))
         (url (issue-link-url issue-id)))
    (if url
        (browse-url url)
      (issue-link--build-link-error issue-id))))

(defun issue-link--parse-remote (url)
  "Parse URL and return a URL struct."
  (let (parts urlobj)
    (unless (string-match "^[a-zA-Z0-9]+://" url)
      (setq url (concat "ssh://" url)))

    (setq urlobj (url-generic-parse-url url))

    (when (and (url-host urlobj)
               (string-match ":" (url-host urlobj)))
      (setq parts (split-string (url-host urlobj) ":" t))
      (setf (url-host urlobj) (car parts)
            (url-filename urlobj) (concat (cadr parts)
                                          (url-filename urlobj))))

    urlobj))

;;;###autoload
(define-minor-mode issue-link-mode
  "Minor mode for turning bug/issue IDs into buttons"
  :lighter ""
  (dolist (pattern `(,issue-link-issue-regexp ,@(mapcar 'car issue-link-issue-alist)))
    (when pattern
      (button-lock-set-button pattern
                              'issue-link--button-click
                              :remove (not issue-link-mode)
                              :keyboard-binding issue-link-keyboard-binding
                              :mouse-binding issue-link-mouse-binding
                              :help-echo "View issue"
                              ;; use comment face for prog-mode + underline????
                              ;; :face 'font-lock-comment-face
                              :face 'link
                              :face-policy 'prepend)))

  (button-lock-mode (if issue-link-mode 1 -1)))

;;;###autoload
(defun issue-link-url (issue-id)
  "Return a URL for the issue given by ISSUE-ID.
`nil' is returned if the URL cannot be constructed."
  (when issue-id
    (or (issue-link--url-for-custom-regexp issue-id)
        (issue-link--url-for-repo issue-id))))

;;;###autoload
(defun issue-link (issue-id)
  "Build a URL for the issue given by ISSUE-ID.
With a prefix argument prompt for ISSUE-ID.

It will always prompt for `ISSUE-ID' if called interactively
and `issue-link-issue-alist' is `nil' and no issue is associated
with the current branch.

An attempt is made to build the link by first trying to match
`ISSUE-ID' with a pattern in `issue-link-issue-alist'. If no match
is found, the link will be built from the branch's remote URL.

If `issue-link-kill' is non-`nil' add the link to the kill ring.
If `issue-link-open-in-browser' is non-`nil' open the link via
`browse-url'.

If the link cannot be build an error is signaled."
  (interactive (list (let (id)
                       (if (or current-prefix-arg
                               (null issue-link-issue-alist)
                               (null (setq id (issue-link--extract-branch-id))))
                           (read-from-minibuffer "Issue ID: ")
                         id))))

  (let ((url (issue-link-url issue-id)))

    (if (not url)
        (issue-link--build-link-error issue-id)

      (when issue-link-kill
        (kill-new url))

      (when issue-link-open-in-browser
        (browse-url url))

      ;; prevent URL escapes from being interpreted as format strings
      (message (replace-regexp-in-string "%" "%%" url t t)))))

(provide 'issue-link)
;;; issue-link.el ends here
