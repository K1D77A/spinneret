(defpackage #:spinneret.tests
  (:use #:cl #:spinneret #:fiveam)
  (:import-from #:alexandria #:ensure-list #:make-keyword)
  (:import-from #:serapeum
    #:~> #:op #:lines #:string-join #:concat)
  (:import-from :spinneret :valid-custom-element-name?)
  (:shadow :test)
  (:export #:run-tests))

(in-package #:spinneret.tests)

(def-suite spinneret)
(in-suite spinneret)

(defmacro test (name &body body)
  `(5am:test (,@(ensure-list name) :compile-at :run-time)
     ;; Ensure the expected defaults.
     (let ((*html-style* :human)
           (*print-pretty* t))
       ,@body)))

(defun run-tests ()
  (run! 'spinneret))

(defun visually-equal (string1 string2)
  (let* ((lines1 (serapeum:lines string1))
         (lines2 (serapeum:lines string2)))
    (and (= (length lines1)
            (length lines2))
         (every (lambda (line1 line2)
                  (equal (string-right-trim " " line1)
                         (string-right-trim " " line2)))
                lines1 lines2))))

(defun linewise-equal (string1 string2)
  (let ((lines1 (mapcar #'serapeum:trim-whitespace (serapeum:lines string1)))
        (lines2 (mapcar #'serapeum:trim-whitespace (serapeum:lines string2))))
    (and (= (length lines1)
            (length lines2))
         (every #'equal lines1 lines2))))

(defmacro with-pretty-printing (&body body)
  `(let ((*print-pretty* t)
         (*html-style* :human))
     ,@body))

(defmacro without-pretty-printing (&body body)
  `(let ((*print-pretty* nil))
     ,@body))

(test dataset
  (without-pretty-printing
    (flet ((dolomphious () 'dolomphious))
      (is (equal
           "<p data-duck=DOLOMPHIOUS data-fish=FIZZGIGIOUS data-spoon=runcible>"
           (with-html-string
             (:p :dataset (:duck (dolomphious) :fish 'fizzgigious
                           :spoon "runcible"))))))))

(test attrs
  (without-pretty-printing
    (is (equal
         "<p foo=bar baz=quux>bar"
         (let ((attrs '(:foo "bar" :baz "quux")))
           (with-html-string (:p :attrs attrs "bar")))))))

(defun bigtable (&optional (*html* *html*))
  (with-html
    (:table
      (dotimes (i 1000)
        (:tr (dotimes (i 10)
               (:td (1+ i))))))))

(test bigtable
  (flet ((bt (msg)
           (let ((start (get-internal-run-time)))
             (with-output-to-string (*html*)
               (finishes (bigtable)))
             (let* ((end (get-internal-run-time))
                    (duration (- end start))
                    (seconds (/ duration (float internal-time-units-per-second))))
               (format t "~&Bigtable benchmark ~a: ~d second~:p~%" msg seconds)))))
    (let ((*print-pretty* t)
          (*html-style* :human))
      (bt "with pretty printing"))
    (let ((*print-pretty* t)
          (*html-style* :tree))
      (bt "with pretty printing (tree style)"))
    (let ((*print-pretty* nil)
          (*html-style* :human))
      (bt "without pretty printing"))
    (let ((*print-pretty* nil)
          (*html-style* :tree))
      (bt "without pretty printing (tree style)"))))

(defun readme-example ()
  (with-pretty-printing
    (let* ((user-name "John Q. Lisper")
           (last-login "12th Never")
           (shopping-list
             '("Atmospheric ponds"
               "Electric gumption socks"
               "Mrs. Leland's embyronic television combustion"
               "Savage gymnatic aggressors"
               "Pharmaceutical pianos"
               "Intravenous retribution champions"))
           (amounts '(10 6 4 9 6 9)))
      (with-html
        (:doctype)
        (:html
          (:head
            (:title "Home page"))
          (:body
            (:header
              (:h1 "Home page"))
            (:section
              ("~A, here is *your* shopping list: " user-name)
              (:ol (loop for item in shopping-list
                         for amount in amounts
                         do (:li amount item))))
            (:footer ("Last login: ~A" last-login))))))))

(defun readme-example-string ()
  (with-output-to-string (*html*)
    (readme-example)))

(test readme-example
  (with-pretty-printing
    (let* ((expected-string
             (format nil "~
<!DOCTYPE html>
<html lang=en>
 <head>
  <meta charset=UTF-8>
  <title>Home page</title>
 </head>
 <body>
  <header>
   <h1>Home page</h1>
  </header>
  <section>
   John Q. Lisper, here is <em>your</em> shopping list:
   <ol>
    <li>10 Atmospheric ponds
    <li>6 Electric gumption socks
    <li>4 Mrs. Leland's embyronic television combustion
    <li>9 Savage gymnatic aggressors
    <li>6 Pharmaceutical pianos
    <li>9 Intravenous retribution champions
   </ol>
  </section>
  <footer>
   Last login: 12th Never
  </footer>
 </body>
</html>"))
           (*print-pretty* t)
           (generated-string
             (readme-example-string)))
      (is (visually-equal generated-string expected-string)))))

(test indent-problem
  (with-pretty-printing
    (is (visually-equal
         (with-html-string
           (:ul (:li (:a "hai"))))
         (format nil "~
<ul>
 <li><a>hai</a>
</ul>")))

    (is (visually-equal
         (with-html-string
           (:html (:head)
             (:body (:a "hai"))))
         (format nil "~
<html lang=en>
 <head>
  <meta charset=UTF-8>
 </head>
 <body>
  <a>hai</a>
 </body>
</html>")))))

(test space-problem
  (without-pretty-printing
    (is
     (equal
      "<div>hello<a href=#></a> there world</div>"
      (spinneret:with-html-string
        (:div "hello"
          (:a :href "#")
          "there world"))))))

(test explicit-spaces
  (without-pretty-printing
    (is (equal "<div>hi<span> there</span></div>"
               (spinneret:with-html-string (:div "hi" (:span " there"))))))
  (with-pretty-printing
    (is (visually-equal
         #.(format nil "~
<p>hi <span>there</span>")
         (let ((*print-pretty* t))
           (spinneret:with-html-string
             (:p "hi " (:span "there"))))))))

(test null-attr
  (without-pretty-printing
    (is (equal (with-html-string (:li :class nil "Hello"))
               "<li>Hello")))
  (without-pretty-printing
    (is (equal (with-html-string (:li :class nil "Hello"))
               "<li>Hello")))

  (is (equal (with-html-string (:li :class (progn nil)))
             "<li>")))

(test no-final-space-after-skipped-attribute
  (without-pretty-printing
    (is (equal (with-html-string (:a :href "#" :data-instant t))
               "<a href=# data-instant=true></a>"))
    (is (equal (with-html-string (:a :href "#" :data-instant nil))
               "<a href=#></a>"))))

(serapeum:def lorem-ipsum
  "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")

(defun lorem-ipsum ()
  (with-pretty-printing
    (let ((*fill-column* 80))
      (with-html
        (:doctype)
        (:html
          (:body
            (:div
              (:p lorem-ipsum (:span)
                (:a :href "" :data-instant t "Hello")
                lorem-ipsum))))))))

(defun lorem-ipsum-string ()
  (with-output-to-string (*html*)
    (lorem-ipsum)))

(test lorem-ipsum
  (is (visually-equal
       #.(format nil
                 "~
<!DOCTYPE html>
<html lang=en>
 <body>
  <div>
   <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
    incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis
    nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
    Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu
    fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
    culpa qui officia deserunt mollit anim id est laborum.<span></span><a href=\"\"
    data-instant=true>Hello</a> Lorem ipsum dolor sit amet, consectetur adipiscing
    elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim
    ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea
    commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit
    esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat
    non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
  </div>
 </body>
</html>")
       (lorem-ipsum-string))))

(test hello-hello-hello
  (with-pretty-printing
    (is (visually-equal
         "<div>
 <div>
  <div>
   <ul>
    <li><a class=\"class1 class2 class3 class4 class5\" href=\"hello hello hello\"></a>
   </ul>
  </div>
 </div>
</div>"
         (spinneret:with-html-string
           (:div
             (:div
               (:div
                 (:ul
                   (:li
                     (:a.class1.class2.class3.class4.class5
                      :href "hello hello hello")))))))))))

(test inline-element-after-paragraph
  (with-pretty-printing
    (is (visually-equal
         (format nil "~
<div>
 <p>Hello
 <a>world</a>
</div>")
         (with-html-string
           (:div
             (:p "Hello")
             (:a "world")))))))

(test indent-attributes-in-blocks
  (with-pretty-printing
    (is (visually-equal
         (format nil "~
<input class=form-control type=password
       name=password id=password required>")
         (with-html-string
           (:input :type "password" :name "password"
             :class "form-control" :id "password"
             :required t))))))

(test indent-text-sanely
  (with-pretty-printing
    (is (linewise-equal
         (format nil "~
   <div class=\"last-update col-xs-2 col-md-1\"
        title=\"Last updated 232 days ago\">
    232d
   </div>")
         (with-html-string
           (:div :class "last-update col-xs-2 col-md-1" :title "Last updated 232 days ago"
             "232d"))))))

(defun indent-string (string n)
  "Add N spaces at the beginning of each line of STRING."
  (let ((padding (make-string n :initial-element #\Space)))
    (~> string
        lines
        (mapcar (op (concat padding _)) _)
        (string-join #\Newline))))

(test indent-sanely-in-blocks-in-paragraphs
  (with-pretty-printing
    (is (serapeum:string*=
         (indent-string
          (with-html-string
            (:div :class "status col-xs-2 col-md-1"
              (:span :class "text-success"
                (:a :href "https://en.wikipedia.org/wiki/List_of_HTTP_status_codes#200"
                  200))))
          ;; Stick an extra space on each line.
          1)
         (with-html-string
           (:li
             (:div :class "status col-xs-2 col-md-1"
               (:span :class "text-success"
                 (:a :href "https://en.wikipedia.org/wiki/List_of_HTTP_status_codes#200"
                   200)))))))))

;; (test (indent-closing-inline-tags-in-blocks :compile-at :run-time)
;;   (let ((*print-pretty* t))
;;     (is (visually-equal
;;          (format nil "~
;; <div>
;;  <span>
;;   <a href=#>Hello</a>
;;  </span>
;; </div>")
;;          (with-html-string
;;            (:div
;;              (:span
;;                (:a :href "#" "Hello"))))))))

(test indent-inline-after-paragraph
  (with-pretty-printing
    (is (visually-equal
         (format nil "~
<p>
 <button>Log in</button>
 <a href=#>Forgot?</a>")
         (with-html-string
           (:p
             (:button "Log in")
             (:a :href "#" "Forgot?")))))))

(test empty-tags-on-same-line
  (with-pretty-printing
    (is (visually-equal
         (format nil "~
<div>
 <div></div>
</div>")
         (with-html-string
           (:div
             (:div)))))))

(test misaligned-attrs-in-nested-blocks
  (with-pretty-printing
    (is (visually-equal
         (format nil "~
<div>
 <div>
  <div>
   <div class=\"list-group toc-entries\"
        data-instant=true></div>
  </div>
 </div>
</div>")
         (with-html-string
           (:div
             (:div
               (:div
                 (:div.list-group.toc-entries
                  :data-instant t)))))))))

(test keywords-in-tokenized-attributes
  (with-pretty-printing
    (is (equal "<p class=foo>"
               (with-html-string
                 (:p :class :foo))))
    (is (equal "<link rel=stylesheet>"
               (with-html-string
                 (:link :rel :stylesheet))))))

(test dynamic-tags
  (with-pretty-printing
    (is (visually-equal
         (with-html-string
           (:div
             (:section
               (:h2
                 (:p "hello")))))
         (with-html-string
           (:div
             (:section
               (:tag :name :h2
                     (:p "hello")))))))))

(test h*
  (with-pretty-printing
    (is (visually-equal
         (format nil "~
<body>
 <h1>This is a top level heading</h1>
 <p>...
 <section>
  <p>...
  <h1>This is a second-level heading</h1>
  <p>...
  <h1>This is another second-level heading</h1>
  <p>...
  <section>
   <h2>This is a third-level heading</h2>
   <p>...
  </section>
 </section>
</body>")
         (with-html-string
           (:body
             (:h* "This is a top level heading")
             (:p "...")
             (:section
               (:p "...")
               (:h* "This is a second-level heading")
               (:p "...")
               (:h* "This is another second-level heading")
               (:p "...")
               (:section
                 (:h* "This is a third-level heading")
                 (:p "...")))))))))


(test print-tree
  (with-pretty-printing
    (is (visually-equal
         (format nil "~
<div>
 <p>Text <a>link text</a> more text
</div>")
         (let ((*html-style* :human))
           (with-html-string
             (:div
               (:p "Text " (:a "link text") " more text"))))))

    (is (visually-equal
         (format nil "~
<div>
 <p>
  Text
  <a>
   link text
  </a>
   more text
 </p>
</div>")
         (let ((*html-style* :tree))
           (with-html-string
             (:div
               (:p "Text " (:a "link text") " more text"))))))))

(test textarea-preformatting
  (flet ((test1 ()
           (with-html-string
             (:div (:textarea "123"))))
         (test2 ()
           (with-html-string
             (let ((*print-pretty*))
               (:div (:textarea "123"))))))
    (with-pretty-printing
      (is (visually-equal (test1)
                          (format nil "~
<div>
 <textarea>123
 </textarea>
</div>")))
      (is (visually-equal (test2)
                          "<div><textarea>123</textarea></div>")))
    ;; Test that dereferencing the underlying stream works when the
    ;; stream is not, in fact, an HTML stream.
    (without-pretty-printing
      (is (visually-equal (test2)
                          "<div><textarea>123</textarea></div>")))))

(test print-as-tree-without-pretty-printing
  (is (visually-equal "<p>hello</p><span>world</span>"
                      (let ((spinneret:*html-style* :tree)
                            (*print-pretty* nil))
                        (spinneret:with-html-string
                          (:p "hello")
                          (:span "world"))))))


(test raw-shouldnt-pretty-print-its-content
  (is (visually-equal
       "Very very very very very very very very very very very very very very very very very very very very very very very very long line"
       (with-html-string
         (:raw "Very very very very very very very very very very very very very very very very very very very very very very very very long line")))))

(test valid-custom-element-names
  (is (not (valid-custom-element-name? :x)))
  (is (not (valid-custom-element-name? :-)))
  (is (not (valid-custom-element-name? :-a)))
  (is (valid-custom-element-name? :a-))
  (is (not (valid-custom-element-name? (make-keyword "a")))))

(test literal-custom-element-names
  (signals error
    (eval
     '(with-html-string
       (:xy "Hello"))))

  (finishes
    (eval
     '(with-html-string
       (:x-y "Hello")))))

(test dynamic-custom-element-names
  (signals error
    (eval
     '(with-html-string
       (:tag :name "xy" "Hello"))))
  (finishes
    (eval
     '(with-html-string
       (:tag :name "x-y" "Hello")))))
