;;; matlivre.el --- MatLivre workspace and figures in Emacs -*- lexical-binding: t; -*-
;; SPDX-License-Identifier: GPL-3.0-or-later
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: languages, tools
;; URL: https://github.com/cristiancmoises/matlibre
;;; Commentary:
;; M-x matlivre opens a command window in GUI or terminal Emacs.
;; Buffers and regions execute in a persistent workspace over local stdio.
;; Upstream connects to an already open MatLivre window when available.
;; Code executes with your user permissions; run only trusted scripts.
;;; Code:
(require 'cl-lib)
(require 'json)
(require 'seq)
(require 'subr-x)
(require 'button)
(require 'octave)
(defgroup matlivre nil "MatLivre scientific computing." :group 'languages)
(defcustom matlivre-program "matlivre" "MatLivre executable." :type 'string)
(defcustom matlivre-timeout 120 "Seconds to wait for a request." :type 'number)
(defvar matlivre--process nil)
(defvar matlivre--id 0)
(defvar matlivre--busy nil)

(defun matlivre-stop ()
  "Stop the stdio connection and discard its headless workspace."
  (interactive)
  (when (processp matlivre--process)
    (let ((buffer (process-buffer matlivre--process)))
      (when (process-live-p matlivre--process) (delete-process matlivre--process))
      (when (buffer-live-p buffer) (kill-buffer buffer))))
  (setq matlivre--process nil))

(defun matlivre--request (method params)
  "Send METHOD with PARAMS; return its JSON-RPC result."
  (when matlivre--busy (user-error "MatLivre already has a pending request"))
  (let ((matlivre--busy t))
    (unless (process-live-p matlivre--process)
      (setq matlivre--process
            (make-process :name "matlivre" :buffer (generate-new-buffer " *matlivre-rpc*")
                          :command (list matlivre-program "--mcp")
                          :coding 'utf-8-unix :connection-type 'pipe :noquery t
                          :sentinel #'ignore
                          :stderr (get-buffer-create "*MatLivre stderr*"))))
    (let* ((id (cl-incf matlivre--id))
           (process matlivre--process)
           (deadline (+ (float-time) matlivre-timeout))
           response)
      (process-send-string process
                           (concat (json-encode `((jsonrpc . "2.0") (id . ,id)
                                                  (method . ,method) (params . ,(or params (make-hash-table))))) "\n"))
      (unwind-protect
          (progn
            (while (and (not response) (process-live-p process) (< (float-time) deadline))
              (accept-process-output process 0.05)
              (with-current-buffer (process-buffer process)
                (goto-char (point-min))
                (while (search-forward "\n" nil t)
                  (let* ((end (point))
                         (message (json-parse-string (buffer-substring-no-properties (point-min) end)
                                                     :object-type 'alist :array-type 'list
                                                     :false-object nil :null-object nil)))
                    (delete-region (point-min) end)
                    (goto-char (point-min))
                    (when (equal (alist-get 'id message) id) (setq response message))))))
            (unless response (error "MatLivre exited or timed out; workspace disconnected"))
            (when-let* ((failure (alist-get 'error response)))
              (error "MatLivre: %s" (alist-get 'message failure)))
            (alist-get 'result response))
        (unless response (matlivre-stop))))))

(defun matlivre-call (tool arguments)
  "Call upstream TOOL with ARGUMENTS, preserving its content and error flag."
  (matlivre--request "tools/call" `((name . ,tool) (arguments . ,(or arguments (make-hash-table))))))

(defun matlivre--text (reply)
  "Collect text from REPLY."
  (mapconcat (lambda (part) (or (alist-get 'text part) "")) (alist-get 'content reply) "\n"))

(defun matlivre--show (reply)
  "Display REPLY text and available PNG images."
  (let ((buffer (get-buffer-create "*MatLivre*")))
    (with-current-buffer buffer
      (unless (derived-mode-p 'matlivre-mode) (matlivre-mode))
      (let ((inhibit-read-only t))
        (goto-char (point-max))
        (insert (if (alist-get 'isError reply) "\nError:\n" "\n"))
        (dolist (part (alist-get 'content reply))
          (pcase (alist-get 'type part)
            ("text" (insert (alist-get 'text part) "\n"))
            ("image"
             (if (and (display-images-p) (image-type-available-p 'png))
                 (insert-image (create-image (base64-decode-string (alist-get 'data part)) 'png t))
               (let ((data (alist-get 'data part)))
                 (insert-text-button
                  "[Save PNG figure]" 'follow-link t
                  'action (lambda (_button)
                            (let ((coding-system-for-write 'no-conversion))
                              (write-region (base64-decode-string data) nil
                                            (read-file-name "Save figure: " nil "figure.png")))))
                 (insert "\n"))))))
        (goto-char (point-max))))
    (pop-to-buffer buffer)))

;;;###autoload
(defun matlivre ()
  "Open MatLivre's command window; use e to evaluate an expression."
  (interactive)
  (matlivre--show (matlivre-call "get_workspace" nil)))
(defun matlivre-eval (code)
  "Evaluate CODE in the persistent workspace."
  (interactive "sMatLivre code: ")
  (matlivre--show (matlivre-call "run_code" `((code . ,code)))))
;;;###autoload
(defun matlivre-run-region (begin end)
  "Execute the region between BEGIN and END."
  (interactive "r")
  (matlivre-eval (buffer-substring-no-properties begin end)))
;;;###autoload
(defun matlivre-run-buffer ()
  "Execute the current buffer, including unsaved edits."
  (interactive)
  (when (and buffer-file-name (string-equal (file-name-extension buffer-file-name) "mlx"))
    (user-error "Open binary .mlx documents with matlivre-open-gui"))
  (matlivre-run-region (point-min) (point-max)))
(defun matlivre-workspace ()
  "Show the current workspace variables."
  (interactive)
  (matlivre--show (matlivre-call "get_workspace" nil)))
(defun matlivre-tool (tool arguments)
  "Discover and call TOOL with JSON ARGUMENTS, including GUI document tools."
  (interactive
   (let* ((tools (alist-get 'tools (matlivre--request "tools/list" nil)))
          (name (completing-read "MatLivre tool: " (mapcar (lambda (x) (alist-get 'name x)) tools) nil t)))
     (list name (json-parse-string (read-string "Arguments (JSON): " "{}") :object-type 'alist))))
  (matlivre--show (matlivre-call tool arguments)))
;;;###autoload
(defun matlivre-open-gui (file)
  "Open FILE in the upstream graphical editor, preserving argument boundaries."
  (interactive (list (read-file-name "MatLivre document: " nil buffer-file-name t)))
  (make-process :name "matlivre-gui" :command (list matlivre-program (expand-file-name file))
                :buffer "*MatLivre GUI*" :noquery t))
(defvar matlivre-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "e") #'matlivre-eval)
    (define-key map (kbd "w") #'matlivre-workspace)
    (define-key map (kbd "t") #'matlivre-tool)
    (define-key map (kbd "k") #'matlivre-stop)
    map))
(define-derived-mode matlivre-mode special-mode "MatLivre" "MatLivre results and workspace.")
(defvar matlivre-script-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") #'matlivre-run-buffer)
    (define-key map (kbd "C-c C-r") #'matlivre-run-region)
    (define-key map (kbd "C-c C-z") #'matlivre)
    (define-key map (kbd "C-c C-w") #'matlivre-workspace)
    (define-key map (kbd "C-c C-o") #'matlivre-open-gui)
    map))
;;;###autoload
(define-derived-mode matlivre-script-mode octave-mode "MatLivre script"
  "Edit MATLAB-compatible scripts for MatLivre.")
;;;###autoload
(defalias 'matlibre #'matlivre)
(provide 'matlivre)
;;; matlivre.el ends here
