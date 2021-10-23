;;; package -- media-editor.el
;;; Commentary:
;;; Code:

(require 'dash)

(defvar-local emeded-current-file nil
  "A plist of storing the file being edited in the current buffer.")

(defvar emeded-temp-directory "/tmp/emeded")

(defvar emeded-waveform-string "|"
  "The character used to make up waveform graphs.")

(defvar emeded-waveform-height 5
  "Height of the waveform graph.")

(defvar emeded-waveform-width 100
  "Width of the waveform graph.")

(defun emeded--file-temp-directory (path)
  "The temp directory used by emeded to store files related to PATH."
  (setq path (expand-file-name path))
  (let ((dir (format "%s/%s" (directory-file-name emeded-temp-directory)
                     (replace-regexp-in-string "/" "!" path))))
    ;; Make the directory if it doesn't exist
    (unless (file-directory-p dir)
      (shell-command-to-string (format "mkdir -p '%s'" dir)))
    dir))

(defun emeded--buffer-name (path)
  "Return the emeded buffer name that should be used for PATH."
  (format "*Emeded %s*"(file-name-nondirectory path)))

(defun emeded--frame-at-time (path time)
  "Return the path to an image of the frame in the video PATH at time TIME.

PATH should be a file path to a video file.
TIME should be a valid ffmpeg timestamp: `[HH:][MM:]SS[.SS]`"

  (let* ((path (expand-file-name path))
         (tmp-dir (emeded--file-temp-directory path))
         (frame-file (format "%s/%s.jpg" tmp-dir time)))
    ;; Use ffmpeg to extract the frame at the correct time
    (unless (file-regular-p frame-file)
      (shell-command-to-string (format "ffmpeg -ss %s -i %s -vframes 1 -q:v 2 %s" time path frame-file)))
    frame-file))

(defun emeded--video-duration (path)
  "Return the duration, as a float, of the video at PATH."
  (string-to-number
   (shell-command-to-string
    (format "ffprobe -i %s -v quiet -show_entries format=duration -hide_banner -of default=noprint_wrappers=1:nokey=1"
            (expand-file-name path)))))

(defun emeded--waveform-graph (path width height)
  "Return a waveform graph of the file at PATH.

The graph will be a list containing HEIGHT strings, where each
string is a row of the graph WIDTH characters long."
  (let ((audio-path (format "%s/audio-levels.txt"(emeded--file-temp-directory path)))
        (count 0) (sum 0)
        lines avgs lines-per-avg min max heights)

    ;; Generate a text file containing a list of the file's audio levels
    (unless (file-regular-p audio-path)
      (message "Reading volume information...")
      (shell-command-to-string (format "touch '%s'" audio-path))
      (shell-command-to-string
       (concat "ffprobe -f lavfi -i amovie=" path
               ",astats=metadata=1:reset=1 -show_entries"
               " frame=pkt_pts_time:frame_tags=lavfi.astats.Overall.RMS_level"
               " -of csv=p=0"
               " | awk -F ',' '{print $2}'"
               " 1> " audio-path)))

    ;; Read the file as a list
    (message "Calculating volume averages...")
    (setq lines (--map (if (string= it "-inf") 0 (/ -1 (string-to-number it)))
                       (split-string (shell-command-to-string
                                      (format "cat '%s'" audio-path))))
          width (min width (length lines))
          lines-per-avg (/ (length lines) width))

    ;; Calculate the averages of ranges of values to get a list WIDTH long
    (while lines
      ;; Add the current volume to the current sum
      (setq sum (+ sum (pop lines))
            count (1+ count))

      ;; Reset the sum and counter when the counter reaches lines-per-avg
      (when (or (>= count lines-per-avg) (null lines))
        (let ((avg (/ sum count)))
          (push avg avgs)
          (setq sum 0 count 0)
          (if (or (null min) (< avg min)) (setq min avg))
          (if (or (null max) (> avg max)) (setq max avg)))))
    (setq avgs (reverse avgs))

    ;; Transform the averages to be an int between 1 and HEIGHT
    (setq heights (--map (if (equal it min) 1
                           (ceiling (* height (/ (- it min) (- max min)))))
                         avgs))

    ;; Turn the list of heights ito a string to be displayed
    (mapconcat (lambda (level)
                 (mapconcat (lambda (h) (if (>= h level) emeded-waveform-string " ")) heights ""))
               (reverse (number-sequence 1 height)) "\n")))

(defun emeded--file-plist (path)
  "Return a plist of properties of the file at PATH."
  (list :path (expand-file-name path)
        :duration (emeded--video-duration path)))

(defun emeded-find-file (path)
  "Edit the file PATH using emeded."
  (interactive "fEdit File: ")
  (let ((buf (emeded--buffer-name path))
        (dir (emeded--file-temp-directory path)))

    ;; Maybe create, then switch to the buffer to edit the file
    (switch-to-buffer (get-buffer-create buf))

    ;; Clear the buffer in case it was being used before
    (read-only-mode 0)
    (delete-region (point-min) (point-max))
    (remove-images (point-min) (point-max))
    
    ;; Set the current file variable
    (setq-local emeded-current-file (emeded--file-plist path))

    ;; Insert the waveform graph
    (insert (emeded--waveform-graph path emeded-waveform-width emeded-waveform-height))

    (read-only-mode 1)))

(defun emeded-display-frame ()
  "Display an image of the frame at the point position in the video.

Figures out the potion of how far the point is through the current
line, multiplies that portion by the video duration, and displays
the frame at this calculated time."
  (let* ((portion (/ (float (current-column))
                     (max 1 (save-excursion (end-of-line) (current-column)))))
         (duration (plist-get emeded-current-file :duration))
         (frame-path (emeded--frame-at-time
                      (plist-get emeded-current-file :path)
                      (number-to-string (* portion (1- duration)))))
         (pixel-width (car (window-text-pixel-size nil (line-beginning-position) (line-end-position))))
         (img (create-image frame-path nil nil :width pixel-width)))
    (remove-images (point-min) (point-max))
    (put-image img (point-max))))

;;; media-editor.el ends here
