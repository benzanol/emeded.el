;;; package -- media-editor.el
;;; Commentary:
;;; Code:

(defun emeded-frame-at-time (path time)
  "Return the path to an image of the frame in the video PATH at time TIME.
PATH should be a file path to a video file.
TIME should be a string with format HH:MM:SS"

  (let* ((path (expand-file-name path))
         (dir-name (replace-regexp-in-string "/" "!" path))
         (tmp-dir (format "/tmp/emacs-media/%s" dir-name))
         (frame-file (format "%s/%s.jpg" tmp-dir time)))
    ;; Make the directory in /tmp if it doesn't exist
    (unless (file-directory-p tmp-dir)
      (shell-command-to-string (format "mkdir -p '%s'" tmp-dir)))

    ;; Use ffmpeg to extract the frame at the correct time
    (shell-command-to-string (format "ffmpeg -ss %s -i %s -vframes 1 -q:v 2 %s" time path frame-file) )
    frame-file))

;;; media-editor.el ends here
