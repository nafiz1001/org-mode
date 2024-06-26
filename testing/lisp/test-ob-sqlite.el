;;; test-ob-sqlite.el --- tests for ob-sqlite.el  -*- lexical-binding: t; -*-

;; Copyright (C) 2017, 2019  Eduardo Bellani

;; Author: Eduardo Bellani <ebellani@gmail.com>
;; Keywords: lisp

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
(org-test-for-executable "sqlite3")
(unless (featurep 'ob-sqlite)
  (signal 'missing-test-dependency '("Support for sqlite code blocks")))

(ert-deftest ob-sqlite/table-variables-with-commas ()
  "Test of a table variable that contains commas. This guarantees that this code path results in a valid CSV."
  (should
   (equal '(("Mr Test A. Sql"
	     "Minister for Science, Eternal Happiness, and Finance"))
	  (org-test-with-temp-text
	      "#+name: test_table1
| \"Mr Test A. Sql\" | Minister for Science, Eternal Happiness, and Finance |

#+begin_src sqlite :db /tmp/test.db :var tb=test_table1
  drop table if exists TestTable;
  create table TestTable(person, job);
  .mode csv TestTable
  .import $tb TestTable
  select * from TestTable;
#+end_src"
	   (org-babel-next-src-block)
	   (org-babel-execute-src-block)))))

(ert-deftest ob-sqlite/in-memory ()
  "Test in-memory temporariness."
  (should
   (equal 0
          (progn
            (org-test-with-temp-text
	     "#+BEGIN_SRC sqlite
PRAGMA user_version = 1;
#+END_SRC"
	     (org-babel-execute-src-block))
            (org-test-with-temp-text
	     "#+BEGIN_SRC sqlite
PRAGMA user_version;
#+END_SRC"
	     (org-babel-execute-src-block))))))

(ert-deftest ob-sqlite/in-file ()
  "Test in-file permanency."
  (should
   (equal 1
          (let ((file (org-babel-temp-file "test" ".sqlite")))
            (org-test-with-temp-text
	     (format "#+BEGIN_SRC sqlite :db %s
PRAGMA user_version = 1;
#+END_SRC" file)
	     (org-babel-execute-src-block))
            (org-test-with-temp-text
	     (format "#+BEGIN_SRC sqlite :db %s
PRAGMA user_version;
#+END_SRC" file)
	     (org-babel-execute-src-block))))))

(provide 'test-ob-sqlite)
;;; test-ob-sqlite.el ends here
