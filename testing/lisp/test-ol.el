;;; test-ol.el --- Tests for Org Links library       -*- lexical-binding: t; -*-

;; Copyright (C) 2019  Nicolas Goaziou

;; Author: Nicolas Goaziou <mail@nicolasgoaziou.fr>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Code:

(require 'cl-lib)
(require 'ol)
(require 'org-id)


;;; Decode and Encode Links

(ert-deftest test-org-link/encode ()
  "Test `org-link-encode' specifications."
  ;; Regural test.
  (should (string= "Foo%3A%42ar" (org-link-encode "Foo:Bar" '(?\: ?\B))))
  ;; Encode an ASCII character.
  (should (string= "%5B" (org-link-encode "[" '(?\[))))
  ;; Encode an ASCII control character.
  (should (string= "%09" (org-link-encode "\t" '(9))))
  ;; Encode a Unicode multibyte character.
  (should (string= "%E2%82%AC" (org-link-encode "€" '(?\€)))))

(ert-deftest test-org-link/decode ()
  "Test `org-link-decode' specifications."
  ;; Decode an ASCII character.
  (should (string= "[" (org-link-decode "%5B")))
  ;; Decode an ASCII control character.
  (should (string= "\n" (org-link-decode "%0A")))
  ;; Decode a Unicode multibyte character.
  (should (string= "€" (org-link-decode "%E2%82%AC"))))

(ert-deftest test-org-link/encode-url-with-escaped-char ()
  "Encode and decode a URL that includes an encoded char."
  (should
   (string= "http://some.host.com/form?&id=blah%2Bblah25"
	    (org-link-decode
	     (org-link-encode "http://some.host.com/form?&id=blah%2Bblah25"
			      '(?\s ?\[ ?\] ?%))))))

(ert-deftest test-org-link/toggle-link-display ()
  "Make sure that `org-toggle-link-display' is working.
See https://github.com/yantar92/org/issues/4."
  (dolist (org-link-descriptive '(nil t))
    (org-test-with-temp-text "* Org link test
[[https://example.com][A link to a site]]"
      (dotimes (_ 2)
        (font-lock-ensure)
        (goto-char 1)
        (re-search-forward "\\[")
        (should-not (org-xor org-link-descriptive (org-invisible-p)))
        (re-search-forward "example")
        (should-not (org-xor org-link-descriptive (org-invisible-p)))
        (re-search-forward "com")
        (should-not (org-xor org-link-descriptive (org-invisible-p)))
        (re-search-forward "]")
        (should-not (org-xor org-link-descriptive (org-invisible-p)))
        (re-search-forward "\\[")
        (should-not (org-invisible-p))
        (re-search-forward "link")
        (should-not (org-invisible-p))
        (re-search-forward "]")
        (should-not (org-xor org-link-descriptive (org-invisible-p)))
        (org-toggle-link-display)))))


;;; Escape and Unescape Links

(ert-deftest test-org-link/escape ()
  "Test `org-link-escape' specifications."
  ;; No-op when there is no backslash or square bracket.
  (should (string= "foo" (org-link-escape "foo")))
  ;; Escape square brackets at boundaries of the link.
  (should (string= "\\[foo\\]" (org-link-escape "[foo]")))
  ;; Escape square brackets followed by another square bracket.
  (should (string= "foo\\]\\[bar" (org-link-escape "foo][bar")))
  (should (string= "foo\\]\\]bar" (org-link-escape "foo]]bar")))
  (should (string= "foo\\[\\[bar" (org-link-escape "foo[[bar")))
  (should (string= "foo\\[\\]bar" (org-link-escape "foo[]bar")))
  ;; Escape backslashes at the end of the link.
  (should (string= "foo\\\\" (org-link-escape "foo\\")))
  ;; Escape backslashes that could be confused with escaping
  ;; characters.
  (should (string= "foo\\\\\\]" (org-link-escape "foo\\]")))
  (should (string= "foo\\\\\\]\\[" (org-link-escape "foo\\][")))
  (should (string= "foo\\\\\\]\\]bar" (org-link-escape "foo\\]]bar")))
  ;; Do not escape backslash characters when unnecessary.
  (should (string= "foo\\bar" (org-link-escape "foo\\bar")))
  ;; Pathological cases: consecutive closing square brackets.
  (should (string= "\\[\\[\\[foo\\]\\]\\]" (org-link-escape "[[[foo]]]")))
  (should (string= "\\[\\[foo\\]\\] bar" (org-link-escape "[[foo]] bar"))))

(ert-deftest test-org-link/unescape ()
  "Test `org-link-unescape' specifications."
  ;; No-op if there is no backslash.
  (should (string= "foo" (org-link-unescape "foo")))
  ;; No-op if backslashes are not escaping backslashes.
  (should (string= "foo\\bar" (org-link-unescape "foo\\bar")))
  ;; Unescape backslashes before square brackets.
  (should (string= "foo]bar" (org-link-unescape "foo\\]bar")))
  (should (string= "foo\\]" (org-link-unescape "foo\\\\\\]")))
  (should (string= "foo\\][" (org-link-unescape "foo\\\\\\][")))
  (should (string= "foo\\]]bar" (org-link-unescape "foo\\\\\\]\\]bar")))
  (should (string= "foo\\[[bar" (org-link-unescape "foo\\\\\\[\\[bar")))
  (should (string= "foo\\[]bar" (org-link-unescape "foo\\\\\\[\\]bar")))
  ;; Unescape backslashes at the end of the link.
  (should (string= "foo\\" (org-link-unescape "foo\\\\")))
  ;; Unescape closing square bracket at boundaries of the link.
  (should (string= "[foo]" (org-link-unescape "\\[foo\\]")))
  ;; Pathological cases: consecutive closing square brackets.
  (should (string= "[[[foo]]]" (org-link-unescape "\\[\\[\\[foo\\]\\]\\]")))
  (should (string= "[[foo]] bar" (org-link-unescape "\\[\\[foo\\]\\] bar"))))

(ert-deftest test-org-link/make-string ()
  "Test `org-link-make-string' specifications."
  ;; Throw an error on empty URI.
  (should-error (org-link-make-string ""))
  ;; Empty description returns a [[URI]] construct.
  (should (string= "[[uri]]"(org-link-make-string "uri")))
  ;; Non-empty description returns a [[URI][DESCRIPTION]] construct.
  (should
   (string= "[[uri][description]]"
	    (org-link-make-string "uri" "description")))
  ;; Escape "]]" strings in the description with zero-width spaces.
  (should
   (let ((zws (string ?\x200B)))
     (string= (format "[[uri][foo]%s]bar]]" zws)
	      (org-link-make-string "uri" "foo]]bar"))))
  ;; Prevent description from ending with a closing square bracket
  ;; with a zero-width space.
  (should
   (let ((zws (string ?\x200B)))
     (string= (format "[[uri][foo]%s]]" zws)
	      (org-link-make-string "uri" "foo]")))))


;;; Store links

(ert-deftest test-org-link/store-link ()
  "Test `org-store-link' specifications."
  ;; On a headline, link to that headline.  Use heading as the
  ;; description of the link.
  (should
   (let (org-store-link-props org-stored-links)
     (org-test-with-temp-text-in-file "* H1"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::*H1][H1]]" file)
		(org-store-link nil))))))
  ;; On a headline, remove TODO and COMMENT keywords, priority cookie,
  ;; and tags.
  (should
   (let (org-store-link-props org-stored-links)
     (org-test-with-temp-text-in-file "* TODO H1"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::*H1][H1]]" file)
		(org-store-link nil))))))
  (should
   (let (org-store-link-props org-stored-links)
     (org-test-with-temp-text-in-file "* COMMENT H1"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::*H1][H1]]" file)
		(org-store-link nil))))))
  (should
   (let (org-store-link-props org-stored-links)
     (org-test-with-temp-text-in-file "* [#A] H1"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::*H1][H1]]" file)
		(org-store-link nil))))))
  (should
   (let (org-store-link-props org-stored-links)
     (org-test-with-temp-text-in-file "* H1 :tag:"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::*H1][H1]]" file)
		(org-store-link nil))))))
  ;; On a headline, remove any link from description.
  (should
   (let (org-store-link-props org-stored-links)
     (org-test-with-temp-text-in-file "* [[#l][d]]"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::*%s][d]]"
			file
			(org-link-escape "[[#l][d]]"))
		(org-store-link nil))))))
  (should
   (let (org-store-link-props org-stored-links)
     (org-test-with-temp-text-in-file "* [[l]]"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::*%s][l]]" file (org-link-escape "[[l]]"))
		(org-store-link nil))))))
  (should
   (let (org-store-link-props org-stored-links)
     (org-test-with-temp-text-in-file "* [[l1][d1]] [[l2][d2]]"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::*%s][d1 d2]]"
			file
			(org-link-escape "[[l1][d1]] [[l2][d2]]"))
		(org-store-link nil))))))
  ;; On a named element, link to that element.
  (should
   (let (org-store-link-props org-stored-links)
     (org-test-with-temp-text-in-file "#+NAME: foo\nParagraph"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::foo][foo]]" file)
		(org-store-link nil))))))
  ;; Store link to Org buffer, with context.
  (should
   (let ((org-stored-links nil)
	 (org-id-link-to-org-use-id nil)
	 (org-context-in-file-links t))
     (org-test-with-temp-text-in-file "* h1"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::*h1][h1]]" file)
		(org-store-link nil))))))
  ;; Store link to Org buffer, without context.
  (should
   (let ((org-stored-links nil)
	 (org-id-link-to-org-use-id nil)
	 (org-context-in-file-links nil))
     (org-test-with-temp-text-in-file "* h1"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s]]" file file)
		(org-store-link nil))))))
  ;; C-u prefix reverses `org-context-in-file-links' in Org buffer.
  (should
   (let ((org-stored-links nil)
	 (org-id-link-to-org-use-id nil)
	 (org-context-in-file-links nil))
     (org-test-with-temp-text-in-file "* h1"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::*h1][h1]]" file)
		(org-store-link '(4)))))))
  ;; A C-u C-u does *not* reverse `org-context-in-file-links' in Org
  ;; buffer.
  (should
   (let ((org-stored-links nil)
	 (org-id-link-to-org-use-id nil)
	 (org-context-in-file-links nil))
     (org-test-with-temp-text-in-file "* h1"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s]]" file file)
		(org-store-link '(16)))))))
  ;; Store file link to non-Org buffer, with context.
  (should
   (let ((org-stored-links nil)
	 (org-link-context-for-files t))
     (org-test-with-temp-text-in-file "one\n<point>two"
       (fundamental-mode)
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::two]]" file)
		(org-store-link nil))))))
  ;; Store file link to non-Org buffer, without context.
  (should
   (let ((org-stored-links nil)
	 (org-context-in-file-links nil))
     (org-test-with-temp-text-in-file "one\n<point>two"
       (fundamental-mode)
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s]]" file file)
		(org-store-link nil))))))
  ;; C-u prefix reverses `org-context-in-file-links' in non-Org
  ;; buffer.
  (should
   (let ((org-stored-links nil)
	 (org-link-context-for-files nil))
     (org-test-with-temp-text-in-file "one\n<point>two"
       (fundamental-mode)
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::two]]" file)
		(org-store-link '(4)))))))
  ;; A C-u C-u does *not* reverse `org-context-in-file-links' in
  ;; non-Org buffer.
  (should
   (let ((org-stored-links nil)
	 (org-context-in-file-links nil))
     (org-test-with-temp-text-in-file "one\n<point>two"
       (fundamental-mode)
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s]]" file file)
		(org-store-link '(16)))))))
  ;; Context does not include special search syntax.
  (should
   (let ((org-stored-links nil)
	 (org-context-in-file-links t))
     (org-test-with-temp-text-in-file "(two)"
       (fundamental-mode)
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::two]]" file file)
		(org-store-link nil))))))
  (should
   (let ((org-stored-links nil)
	 (org-context-in-file-links t))
     (org-test-with-temp-text-in-file "#two"
       (fundamental-mode)
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::two]]" file file)
		(org-store-link nil))))))
  (should
   (let ((org-stored-links nil)
	 (org-context-in-file-links t))
     (org-test-with-temp-text-in-file "*two"
       (fundamental-mode)
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::two]]" file file)
		(org-store-link nil))))))
  (should
   (let ((org-stored-links nil)
	 (org-context-in-file-links t))
     (org-test-with-temp-text-in-file "( two )"
       (fundamental-mode)
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::two]]" file file)
		(org-store-link nil))))))
  (should
   (let ((org-stored-links nil)
	 (org-context-in-file-links t))
     (org-test-with-temp-text-in-file "# two"
       (fundamental-mode)
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::two]]" file file)
		(org-store-link nil))))))
  (should
   (let ((org-stored-links nil)
	 (org-context-in-file-links t))
     (org-test-with-temp-text-in-file "#( two )"
       (fundamental-mode)
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::two]]" file file)
		(org-store-link nil))))))
  (should
   (let ((org-stored-links nil)
	 (org-context-in-file-links t))
     (org-test-with-temp-text-in-file "#** ((## two) )"
       (fundamental-mode)
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::two]]" file file)
		(org-store-link nil))))))
  (should-not
   (let ((org-stored-links nil)
	 (org-context-in-file-links t))
     (org-test-with-temp-text-in-file "(two"
       (fundamental-mode)
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::two]]" file file)
		(org-store-link nil))))))
  ;; Context also ignore statistics cookies and special headlines
  ;; data.
  (should
   (let ((org-stored-links nil)
	 (org-context-in-file-links t))
     (org-test-with-temp-text-in-file "* TODO [#A] COMMENT foo :bar:"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::*foo][foo]]" file file)
		(org-store-link nil))))))
  (should
   (let ((org-stored-links nil)
	 (org-context-in-file-links t))
     (org-test-with-temp-text-in-file "* foo[33%]bar"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::*foo bar][foo bar]]" file file)
		(org-store-link nil))))))
  (should
   (let ((org-stored-links nil)
	 (org-context-in-file-links t))
     (org-test-with-temp-text-in-file "* [%][/]  foo [35%] bar[3/5]"
       (let ((file (buffer-file-name)))
	 (equal (format "[[file:%s::*foo bar][foo bar]]" file file)
		(org-store-link nil)))))))

(ert-deftest test-org-link/precise-link-target ()
  "Test `org-link-precise-link-target` specifications."
  (org-test-with-temp-text "* H1<point>\n* H2\n"
    (should
     (equal '("*H1" "H1" 1)
            (org-link-precise-link-target))))
  (org-test-with-temp-text "* H1\n#+name: foo<point>\n#+begin_example\nhi\n#+end_example\n"
    (should
     (equal '("foo" "foo" 6)
            (org-link-precise-link-target))))
  (org-test-with-temp-text "\nText<point>\n* H1\n"
    (should
     (equal '("Text" nil 2)
            (org-link-precise-link-target))))
  (org-test-with-temp-text "\n<point>\n* H1\n"
    (should
     (equal nil (org-link-precise-link-target)))))

(defmacro test-ol-stored-link-with-text (text &rest body)
  "Return :link and :description from link stored in body."
  (declare (indent 1))
  `(let (org-store-link-plist)
     (org-test-with-temp-text-in-file ,text
       ,@body
       (list (plist-get org-store-link-plist :link)
             (plist-get org-store-link-plist :description)))))

(ert-deftest test-org-link/id-store-link ()
  "Test `org-id-store-link' specifications."
  (let ((org-id-link-to-org-use-id nil))
    (should
     (equal '(nil nil)
            (test-ol-stored-link-with-text "* H1\n:PROPERTIES:\n:ID: abc\n:END:\n"
              (org-id-store-link-maybe t)))))
  ;; On a headline, link to that headline's ID.  Use heading as the
  ;; description of the link.
  (let ((org-id-link-to-org-use-id t))
    (should
     (equal '("id:abc" "H1")
            (test-ol-stored-link-with-text "* H1\n:PROPERTIES:\n:ID: abc\n:END:\n"
              (org-id-store-link-maybe t)))))
  ;; Remove TODO keywords etc from description of the link.
  (let ((org-id-link-to-org-use-id t))
    (should
     (equal '("id:abc" "H1")
            (test-ol-stored-link-with-text "* TODO [#A] H1 :tag:\n:PROPERTIES:\n:ID: abc\n:END:\n"
              (org-id-store-link-maybe t)))))
  ;; create-if-interactive
  (let ((org-id-link-to-org-use-id 'create-if-interactive))
    (should
     (equal '("id:abc" "H1")
            (cl-letf (((symbol-function 'org-id-new)
                       (lambda (&rest _rest) "abc")))
              (test-ol-stored-link-with-text "* H1\n"
                (org-id-store-link-maybe t)))))
    (should
     (equal '(nil nil)
            (test-ol-stored-link-with-text "* H1\n"
              (org-id-store-link-maybe nil)))))
  ;; create-if-interactive-and-no-custom-id
  (let ((org-id-link-to-org-use-id 'create-if-interactive-and-no-custom-id))
    (should
     (equal '("id:abc" "H1")
            (cl-letf (((symbol-function 'org-id-new)
                       (lambda (&rest _rest) "abc")))
              (test-ol-stored-link-with-text "* H1\n"
                (org-id-store-link-maybe t)))))
    (should
     (equal '(nil nil)
            (test-ol-stored-link-with-text "* H1\n:PROPERTIES:\n:CUSTOM_ID: xyz\n:END:\n"
              (org-id-store-link-maybe t))))
    (should
     (equal '(nil nil)
            (test-ol-stored-link-with-text "* H1\n"
              (org-id-store-link-maybe nil)))))
  ;; use-context should have no effect when on the headline with an id
  (let ((org-id-link-to-org-use-id t)
        (org-id-link-use-context t))
    (should
     (equal '("id:abc" "H2")
            (test-ol-stored-link-with-text "* H1\n** H2<point>\n:PROPERTIES:\n:ID: abc\n:END:\n"
              ;; simulate previously getting an inherited value
              (move-marker org-entry-property-inherited-from 1)
              (org-id-store-link-maybe t))))))

(ert-deftest test-org-link/id-store-link-using-parent ()
  "Test `org-id-store-link' specifications with `org-id-link-consider-parent-id` set."
  ;; when using context to still find specific heading
  (let ((org-id-link-to-org-use-id t)
        (org-id-link-consider-parent-id t)
        (org-id-link-use-context t))
    (should
     (equal '("id:abc::*H2" "H2")
            (test-ol-stored-link-with-text "* H1\n:PROPERTIES:\n:ID: abc\n:END:\n** H2\n<point>"
              (org-id-store-link))))
    (should
     (equal '("id:abc::name" "name")
            (test-ol-stored-link-with-text "* H1\n:PROPERTIES:\n:ID: abc\n:END:\n\n#+name: name\n<point>#+begin_example\nhi\n#+end_example\n"
              (org-id-store-link))))
    (should
     (equal '("id:abc" "H1")
            (test-ol-stored-link-with-text "* H1<point>\n:PROPERTIES:\n:ID: abc\n:END:\n** H2\n"
              (org-id-store-link))))
    ;; should not use newly added ids as search string, e.g. in an empty file
    (should
     (let (name result)
       (setq result
             (cl-letf (((symbol-function 'org-id-new)
                        (lambda (&rest _rest) "abc")))
               (test-ol-stored-link-with-text "<point>"
                 (setq name (buffer-name))
                 (org-id-store-link))))
       (equal `("id:abc" ,name) result))))
  ;; should not find targets in the next section
  (let ((org-id-link-to-org-use-id 'use-existing)
        (org-id-link-consider-parent-id t)
        (org-id-link-use-context t))
    (should
     (equal '(nil nil)
            (test-ol-stored-link-with-text "* H1\n:PROPERTIES:\n:ID: abc\n:END:\n* H2\n** <point>Target\n"
              (org-id-store-link-maybe t))))))


;;; Radio Targets

(ert-deftest test-org-link/update-radio-target-regexp ()
  "Test `org-update-radio-target-regexp' specifications."
  ;; Properly update cache with no previous radio target regexp.
  (should
   (eq 'link
       (org-test-with-temp-text "radio\n\nParagraph\n\nradio"
	 (save-excursion (goto-char (point-max)) (org-element-context))
	 (insert "<<<")
	 (search-forward "o")
	 (insert ">>>")
	 (org-update-radio-target-regexp)
	 (goto-char (point-max))
	 (org-element-type (org-element-context)))))
  ;; Properly update cache with previous radio target regexp.
  (should
   (eq 'link
       (org-test-with-temp-text "radio\n\nParagraph\n\nradio"
	 (save-excursion (goto-char (point-max)) (org-element-context))
	 (insert "<<<")
	 (search-forward "o")
	 (insert ">>>")
	 (org-update-radio-target-regexp)
	 (search-backward "r")
	 (delete-char 5)
	 (insert "new")
	 (org-update-radio-target-regexp)
	 (goto-char (point-max))
	 (delete-region (line-beginning-position) (point))
	 (insert "new")
	 (org-element-type (org-element-context))))))


;;; Navigation

(ert-deftest test-org-link/next-link ()
  "Test `org-next-link' specifications."
  ;; Move to any type of link.
  (should
   (equal "[[link]]"
	  (org-test-with-temp-text "foo [[link]]"
	    (org-next-link)
	    (buffer-substring (point) (line-end-position)))))
  (should
   (equal "http://link"
	  (org-test-with-temp-text "foo http://link"
	    (org-next-link)
	    (buffer-substring (point) (line-end-position)))))
  (should
   (equal "<http://link>"
	  (org-test-with-temp-text "foo <http://link>"
	    (org-next-link)
	    (buffer-substring (point) (line-end-position)))))
  ;; Ignore link at point.
  (should
   (equal "[[link2]]"
	  (org-test-with-temp-text "[[link1]] [[link2]]"
	    (org-next-link)
	    (buffer-substring (point) (line-end-position)))))
  ;; Ignore fake links.
  (should
   (equal "[[truelink]]"
	  (org-test-with-temp-text "foo\n: [[link]]\n[[truelink]]"
	    (org-next-link)
	    (buffer-substring (point) (line-end-position)))))
  ;; Do not move point when there is no link.
  (should
   (org-test-with-temp-text "foo bar"
     (org-next-link)
     (bobp)))
  ;; Wrap around after a failed search.
  (should
   (equal "[[link]]"
	  (org-test-with-temp-text "[[link]]\n<point>foo"
	    (org-next-link)
	    (let* ((this-command 'org-next-link)
		   (last-command this-command))
	      (org-next-link))
	    (buffer-substring (point) (line-end-position)))))
  ;; Find links with item tags.
  (should
   (equal "[[link1]]"
	  (org-test-with-temp-text "- tag [[link1]] :: description"
	    (org-next-link)
	    (buffer-substring (point) (search-forward "]]" nil t))))))

(ert-deftest test-org-link/previous-link ()
  "Test `org-previous-link' specifications."
  ;; Move to any type of link.
  (should
   (equal "[[link]]"
	  (org-test-with-temp-text "[[link]]\nfoo<point>"
	    (org-previous-link)
	    (buffer-substring (point) (line-end-position)))))
  (should
   (equal "http://link"
	  (org-test-with-temp-text "http://link\nfoo<point>"
	    (org-previous-link)
	    (buffer-substring (point) (line-end-position)))))
  (should
   (equal "<http://link>"
	  (org-test-with-temp-text "<http://link>\nfoo<point>"
	    (org-previous-link)
	    (buffer-substring (point) (line-end-position)))))
  ;; Ignore link at point.
  (should
   (equal "[[link1]]"
	  (org-test-with-temp-text "[[link1]]\n[[link2<point>]]"
	    (org-previous-link)
	    (buffer-substring (point) (line-end-position)))))
  (should
   (equal "[[link1]]"
	  (org-test-with-temp-text "line\n[[link1]]\n[[link2<point>]]"
	    (org-previous-link)
	    (buffer-substring (point) (line-end-position)))))
  ;; Ignore fake links.
  (should
   (equal "[[truelink]]"
	  (org-test-with-temp-text "[[truelink]]\n: [[link]]\n<point>"
	    (org-previous-link)
	    (buffer-substring (point) (line-end-position)))))
  ;; Do not move point when there is no link.
  (should
   (org-test-with-temp-text "foo bar<point>"
     (org-previous-link)
     (eobp)))
  ;; Wrap around after a failed search.
  (should
   (equal "[[link]]"
	  (org-test-with-temp-text "foo\n[[link]]"
	    (org-previous-link)
	    (let* ((this-command 'org-previous-link)
		   (last-command this-command))
	      (org-previous-link))
	    (buffer-substring (point) (line-end-position))))))


;;; Link regexps


(defmacro test-ol-parse-link-in-text (text)
  "Return list of :type and :path of link parsed in TEXT.
\"<point>\" string must be at the beginning of the link to be parsed."
  (declare (indent 1))
  `(org-test-with-temp-text ,text
     (list (org-element-property :type (org-element-link-parser))
           (org-element-property :path (org-element-link-parser)))))

(ert-deftest test-org-link/plain-link-re ()
  "Test `org-link-plain-re'."
  (should
   (equal
    '("https" "//example.com")
    (test-ol-parse-link-in-text
        "(<point>https://example.com)")))
  (should
   (equal
    '("https" "//example.com/qwe()")
    (test-ol-parse-link-in-text
        "(Some text <point>https://example.com/qwe())")))
  (should
   (equal
    '("https" "//doi.org/10.1016/0160-791x(79)90023-x")
    (test-ol-parse-link-in-text
        "<point>https://doi.org/10.1016/0160-791x(79)90023-x")))
  (should
   (equal
    '("file" "aa")
    (test-ol-parse-link-in-text
        "The <point>file:aa link")))
  (should
   (equal
    '("file" "a(b)c")
    (test-ol-parse-link-in-text
        "The <point>file:a(b)c link")))
  (should
   (equal
    '("file" "a()")
    (test-ol-parse-link-in-text
        "The <point>file:a() link")))
  (should
   (equal
    '("file" "aa((a))")
    (test-ol-parse-link-in-text
        "The <point>file:aa((a)) link")))
  (should
   (equal
    '("file" "aa(())")
    (test-ol-parse-link-in-text
        "The <point>file:aa(()) link")))
  (should
   (equal
    '("file" "/a")
    (test-ol-parse-link-in-text
        "The <point>file:/a link")))
  (should
   (equal
    '("file" "/a/")
    (test-ol-parse-link-in-text
        "The <point>file:/a/ link")))
  (should
   (equal
    '("http" "//")
    (test-ol-parse-link-in-text
        "The <point>http:// link")))
  (should
   (equal
    '("file" "ab")
    (test-ol-parse-link-in-text
        "The (some <point>file:ab) link")))
  (should
   (equal
    '("file" "aa")
    (test-ol-parse-link-in-text
        "The <point>file:aa) link")))
  (should
   (equal
    '("file" "aa")
    (test-ol-parse-link-in-text
        "The <point>file:aa( link")))
  (should
   (equal
    '("http" "//foo.com/more_(than)_one_(parens)")
    (test-ol-parse-link-in-text
        "The <point>http://foo.com/more_(than)_one_(parens) link")))
  (should
   (equal
    '("http" "//foo.com/blah_(wikipedia)#cite-1")
    (test-ol-parse-link-in-text
        "The <point>http://foo.com/blah_(wikipedia)#cite-1 link")))
  (should
   (equal
    '("http" "//foo.com/blah_(wikipedia)_blah#cite-1")
    (test-ol-parse-link-in-text
        "The <point>http://foo.com/blah_(wikipedia)_blah#cite-1 link")))
  (should
   (equal
    '("http" "//foo.com/unicode_(✪)_in_parens")
    (test-ol-parse-link-in-text
        "The <point>http://foo.com/unicode_(✪)_in_parens link")))
  (should
   (equal
    '("http" "//foo.com/(something)?after=parens")
    (test-ol-parse-link-in-text
        "The <point>http://foo.com/(something)?after=parens link"))))

;;; Insert Links

(defmacro test-ol-with-link-parameters-as (type parameters &rest body)
  "Pass TYPE/PARAMETERS to `org-link-parameters' and execute BODY.

Save the original value of `org-link-parameters', execute
`org-link-set-parameters' with the relevant args, execute BODY
and restore `org-link-parameters'.

TYPE is as in `org-link-set-parameters'.  PARAMETERS is a plist to
be passed to `org-link-set-parameters'."
  (declare (indent 2))
  (let (orig-parameters)
    ;; Copy all keys in `parameters' and their original values to
    ;; `orig-parameters'.
    (cl-loop for param in parameters by 'cddr
             do (setq orig-parameters
                      (plist-put orig-parameters param (org-link-get-parameter type param))))
    `(unwind-protect
         ;; Set `parameters' values and execute body.
         (progn (org-link-set-parameters ,type ,@parameters) ,@body)
       ;; Restore original values.
       (apply 'org-link-set-parameters ,type ',orig-parameters))))

(defun test-ol-insert-link-get-desc (&optional link-location description)
  "Insert link in temp buffer, return description.

LINK-LOCATION and DESCRIPTION are passed to
`org-insert-link' (COMPLETE-FILE is always nil)."
  (org-test-with-temp-text ""
    (org-insert-link nil link-location description)
    (save-match-data
      (when (and
             (org-in-regexp org-link-bracket-re 1)
             (match-end 2))
        (match-string-no-properties 2)))))

(defun test-ol/return-foobar (_link-test _desc)
  "Return string \"foobar\".

Take (and ignore) arguments conforming to `:insert-description'
API in `org-link-parameters'.  Used in test
`test-ol/insert-link-insert-description', for the case where
`:insert-description' is a function symbol."
  "foobar-from-function")

(ert-deftest test-org-link/insert-link-insert-description ()
  "Test `:insert-description' parameter handling."
  ;; String case.
  (should
   (string=
    "foobar-string"
    (test-ol-with-link-parameters-as
        "id" (:insert-description "foobar-string")
      (test-ol-insert-link-get-desc "id:foo-bar"))))
  ;; Lambda case.
  (should
   (string=
    "foobar-lambda"
    (test-ol-with-link-parameters-as
        "id" (:insert-description (lambda (_link-test _desc) "foobar-lambda"))
      (test-ol-insert-link-get-desc "id:foo-bar"))))
  ;; Function symbol case.
  (should
   (string=
    "foobar-from-function"
    (test-ol-with-link-parameters-as
        "id" (:insert-description #'test-ol/return-foobar)
      (test-ol-insert-link-get-desc "id:foo-bar"))))
  ;; `:insert-description' parameter is defined, but doesn't return a
  ;; string.
  (should
   (null
    (test-ol-with-link-parameters-as
        "id" (:insert-description #'ignore)
      (test-ol-insert-link-get-desc "id:foo-bar"))))
  ;; Description argument should override `:insert-description'.
  (should
   (string=
    "foobar-desc-arg"
    (test-ol-with-link-parameters-as
        "id" (:insert-description "foobar")
      (test-ol-insert-link-get-desc "id:foo-bar" "foobar-desc-arg"))))
  ;; When neither `:insert-description' nor
  ;; `org-link-make-description-function' is defined, there should be
  ;; no description
  (should
   (null
    (let ((org-link-make-description-function nil))
      (test-ol-insert-link-get-desc "fake-link-type:foo-bar")))))

(provide 'test-ol)
;;; test-ol.el ends here
