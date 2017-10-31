# eim-peep-dired
A modified version of peep-dired optimized for viewing images.


# Overview
This is an alternative to peep-dired that modifies the
original package in the following ways:
 
1. It uses the [Emacs Image Manipulation Package](https://www.emacswiki.org/emacs/EmacsImageManipulation)
   to automatically re-size images to fit the peep-dired
   window when peep-dired mode is enabled or on invoking
   peep-dired-snext-file or peep-dired-sprev-file.
    
2. It marks image buffers as unmodified so that the user
   is not prompted to save the changes caused by the
   re-sizing operation.
    
3. It kills peeped buffers on invoking peep-dired-snext-file
   or peep-dired-sprev-file.  This means peep-dired acts like
   a typical photo viewer application (rather than opening new
   files in separate windows) and keeps the buffer 
   list clean.
    
4. Several of the original key-bindings are altered.
 
eim-peep-dired contains all of the original peep-dired functions
and can be used with other file types besides images. 


# Requirements
1. ImageMagick:
http://www.imagemagick.org
   
2. Emacs Image Manipulation Package:
https://www.emacswiki.org/emacs/EmacsImageManipulation  
See the 'talk' page for configuration help.
 
 
# Installation
Download eim-peep-dired.el and use 'M-x package-install-file' after 
installing the above requirements. 


# Configuration
```emacs
(use-package eim-peep-dired
  :ensure t
  :defer t ; don't access `dired-mode-map' until `eim-peep-dired' is loaded
  :bind (:map dired-mode-map
              ("," . eim-peep-dired)
  :config
  (setq eim-peep-dired-cleanup-eagerly nil) 
  (setq eim-peep-dired-cleanup-on-disable t)))
```

# Usage
When in a dired buffer, press "," to turn on eim-peep-dired and view the 
file at point in a separate window.  The package automatically fits 
the image to the window.  C-n/C-p move to the next and previous
entries in the dired buffer.  When moving to a new entry, the 
previous peep preview buffer is killed.  If you prefer to compare files 
in separate windows at the same time, use M-n/M-p instead of C-n/C-p.  


## Commands
```
,       Enable eim-peep-dired from a dired buffer
C-n     View the next file in the same peep window
C-p     View the previous file in the same peep window
M-n     View the next file in a separate peep window
M-p     View the previous file in a separate peep window
SPC     Scroll the peeped buffer down
C-SPC   Scroll the peeped buffer up
```

# Limitations
1. The re-sizing operation relies on the mogrify function
   provided by ImageMagick.  This runs slowly for larger 
   images.  For this reason, the operation that marks
   the buffer as unmodified can sometimes finish before
   the re-sizing operation finishes.  In this instance,
   the user will be asked whether or not to save the
   changes to the image when disabling eim-peep-dired.  If 
   you plan to work with many large images, you can 
   modify the timer settings in the source file.  The 
   default is 0.250 sec.


# Acknowledgement
Thank you to @asok for the original [peep-dired](https://github.com/asok/peep-dired), one of my favorite 
emacs packages. 

   
   
