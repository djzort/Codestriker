<!DOCTYPE style-sheet PUBLIC "-//James Clark//DTD DSSSL Style Sheet//EN" [
     <!ENTITY html-ss 
       PUBLIC "-//Norman Walsh//DOCUMENT DocBook HTML Stylesheet//EN" CDATA dsssl>
     <!ENTITY print-ss
       PUBLIC "-//Norman Walsh//DOCUMENT DocBook Print Stylesheet//EN" CDATA dsssl>
     ]>
     <style-sheet>
     <style-specification id="print" use="print-stylesheet">
     <style-specification-body> 

     ;; customize the print stylesheet
     (define %paper-type% "A4")
     (define %section-autolabel% #t)
     (define %nochunks% #t)
     (define %body-start-indent% 0pi)
     (define (book-titlepage-recto-elements)
         (list (normalize "title")
             (normalize "subtitle")
             (normalize "authorgroup")
             (normalize "author")
             (normalize "releaseinfo")
             (normalize "copyright")
             (normalize "pubdate")
             (normalize "revhistory")
             (normalize "legalnotice")
             (normalize "affiliation")
             (normalize "abstract")))
     (define (article-titlepage-recto-elements)
         (list (normalize "title")
             (normalize "subtitle")
             (normalize "authorgroup")
             (normalize "author")
             (normalize "releaseinfo")
             (normalize "copyright")
             (normalize "pubdate")
             (normalize "revhistory")
             (normalize "legalnotice")
             (normalize "affiliation")
             (normalize "abstract")))
     </style-specification-body>
     </style-specification>
     <style-specification id="html" use="html-stylesheet">
     <style-specification-body> 

     ;; customize the html stylesheet
     (define %html-ext% ".html")
     (define %section-autolabel% #t)
     (define (book-titlepage-recto-elements)
         (list (normalize "title")
             (normalize "subtitle")
             (normalize "authorgroup")
             (normalize "author")
             (normalize "releaseinfo")
             (normalize "copyright")
             (normalize "pubdate")
             (normalize "revhistory")
             (normalize "legalnotice")
             (normalize "affiliation")
             (normalize "abstract")))
     (define (article-titlepage-recto-elements)
         (list (normalize "title")
             (normalize "subtitle")
             (normalize "authorgroup")
             (normalize "author")
             (normalize "releaseinfo")
             (normalize "copyright")
             (normalize "pubdate")
             (normalize "revhistory")
             (normalize "legalnotice")
             (normalize "affiliation")
             (normalize "abstract")))

     </style-specification-body>
     </style-specification>
     <external-specification id="print-stylesheet" document="print-ss">
     <external-specification id="html-stylesheet"  document="html-ss">
     </style-sheet>
