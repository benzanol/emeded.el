;;; package -- media-editor.el
;;; Commentary:
;;; Code:

(defvar-local emeded-current-file nil
  "A plist of storing the file being edited in the current buffer.")

(defun emeded--frame-at-time (path time)
  "Return the path to an image of the frame in the video PATH at time TIME.

PATH should be a file path to a video file.
TIME should be a valid ffmpeg timestamp: `[HH:][MM:]SS[.SS]`"

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

(defun emeded--video-duration (path)
  "Return the duration, as a float, of the video at PATH."
  (string-to-number
   (shell-command-to-string
    (format "ffprobe -i %s -v quiet -show_entries format=duration -hide_banner -of default=noprint_wrappers=1:nokey=1"
            (expand-file-name path)))))

(defun emeded--file-plist (path)
  "Return a plist of properties of the file at PATH."
  (list :path (expand-file-name path)
        :duration (emeded--video-duration path)))

(defun emeded-find-file (path)
  "Edit the file PATH using emeded."
  (interactive "fEdit File: ")
  (setq-local emeded-current-file (emeded--file-plist path)))

;;; media-editor.el ends here
