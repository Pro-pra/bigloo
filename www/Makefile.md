#*=====================================================================*/
#*    serrano/prgm/project/bigloo/bigloo/www/Makefile.md               */
#*    -------------------------------------------------------------    */
#*    Author      :  Manuel Serrano                                    */
#*    Creation    :  Mon May  4 16:13:02 2020                          */
#*    Last change :  Sun May 10 14:11:42 2020 (serrano)                */
#*    Copyright   :  2020 Manuel Serrano                               */
#*    -------------------------------------------------------------    */
#*    WWW Bigloo page                                                  */
#*=====================================================================*/
do: build

#*---------------------------------------------------------------------*/
#*    Configuration                                                    */
#*---------------------------------------------------------------------*/
HOP=hop
HOPFLAGS=-q --no-autoload --no-zeroconf --no-server --so-policy none

#*---------------------------------------------------------------------*/
#*    Destination                                                      */
#*---------------------------------------------------------------------*/
INDESHTTP	= www-sop.inria.fr/indes/fp
HOSTHTTP	= $(INDESHTTP)
HOSTHTTPDIR	= /users/serrano/public_html/bigloo
HOSTURL		= http://$(HOSTHTTP)/Bigloo

#*---------------------------------------------------------------------*/
#*    Population                                                       */
#*---------------------------------------------------------------------*/
BOOTSTRAP_POP=css/bootstrap.css css/bootstrap.min.css css/bootstrap.css.map \
  css/bootstrap-theme.css css/bootstrap-theme.min.css css/bootstrap-theme.css.map \
  js/bootstrap.js js/bootstrap.min.js  js/npm.js \
  fonts/glyphicons-halflings-regular.eot \
  fonts/glyphicons-halflings-regular.woff \
  fonts/glyphicons-halflings-regular.svg \
  fonts/glyphicons-halflings-regular.woff2 \
  fonts/glyphicons-halflings-regular.ttf

JQUERY_POP=js/jquery.min.js

POP=bib.md cross.md documentation.md homebrew.md license.md manual.md \
  contribs.md debian.md download.md _index.md \
  doc.hss  fontifier.css  markdown.css  texinfo.css \
  $(BOOTSTRAP_POP) $(JQUERY_POP) \
  favicon.png bigloo.svg \
  fib.scm fib-mt.scm flac.scm \
  Makefile.md

ALL_TARGETS=index.html license.html download.html debian.html homebrew.html \
  manual.html bib.html contribs.html cross.html

#*---------------------------------------------------------------------*/
#*    The hop executable                                               */
#*---------------------------------------------------------------------*/
.PHONY: build clean install uninstall

build: $(ALL_TARGETS) hss/doc.css idx.html

#*---------------------------------------------------------------------*/
#*    clean                                                            */
#*---------------------------------------------------------------------*/
clean:
	rm -f $(ALL_TARGETS)
	rm -f manual-chapter*.html
	$(RM) idx.json idx.html

devclean: clean

distclean: clean

#*---------------------------------------------------------------------*/
#*    Install                                                          */
#*---------------------------------------------------------------------*/
install: all $(DOC)
	cleanup
	$(MAKE) install.start
	$(MAKE) install.html
	$(MAKE) install.stop

#*--- install.start ---------------------------------------------------*/
install.start:
	ssh $(HOSTFTP) "cd $(HOSTFTPHOMEDIR)$(HOSTFTPDIR); chmod u+w -R ."
	ssh $(HOSTHTTP) "mkdir -p $(HOSTHTTPHOMEDIR)$(HOSTHTTPDIR); cd $(HOSTHTTPHOMEDIR)$(HOSTHTTPDIR); chmod u+w -R ."

#*--- install.stop ----------------------------------------------------*/
install.stop:
	ssh $(HOSTFTP) "cd $(HOSTFTPHOMEDIR)$(HOSTFTPDIR); chmod a-w -R ."
	ssh $(HOSTHTTP) "cd $(HOSTHTTPHOMEDIR)$(HOSTHTTPDIR); chmod a-w -R ."

#*--- install.html ----------------------------------------------------*/
install.html:
	for p in *.html; do \
	  scp $$p $(HOSTHTTP):$(HOSTHTTPDIR)/$$p; \
        done
	scp -r hss $(HOSTHTTP):$(HOSTHTTPDIR)/hss
	scp -r lib $(HOSTHTTP):$(HOSTHTTPDIR)/lib
	ssh $(HOSTHTTP) "cd $(HOSTHTTPDIR); chmod a+r *.html"
	ssh $(HOSTHTTP) "cd $(HOSTHTTPDIR); chmod -R a+r lib"
	ssh $(HOSTHTTP) "cd $(HOSTHTTPDIR); chmod -R a+r hss"

#*---------------------------------------------------------------------*/
#*    pop ...                                                          */
#*---------------------------------------------------------------------*/
pop:
	@ echo $(POPULATION:%=www/%)

#*---------------------------------------------------------------------*/
#*    Suffixes                                                         */
#*---------------------------------------------------------------------*/
.SUFFIXES: .md .html .json

#*---------------------------------------------------------------------*/
#*    .md -> .html                                                     */
#*---------------------------------------------------------------------*/
%.html: %.md doc.js xml.js bigloo.svg doc.json
	$(HOP) $(HOPFLAGS) $(EFLAGS) -- \
          ./doc.js "compile-section" $< > $@ \
          || ($(RM) $@; exit 1)

#*---------------------------------------------------------------------*/
#*    .json -> .html                                                   */
#*---------------------------------------------------------------------*/
%.html: %.json doc.js xml.js bigloo.svg doc.json
	$(HOP) $(HOPFLAGS) $(EFLAGS) -- \
          ./doc.js "compile-chapter" $< > $@ \
          || ($(RM) $@; exit 1)

#*---------------------------------------------------------------------*/
#*    index.html ...                                                   */
#*---------------------------------------------------------------------*/
index.html: _index.md doc.js xml.js bigloo.svg doc.json
	$(HOP) $(HOPFLAGS) $(EFLAGS) -- \
          ./doc.js "compile-main" $< > $@ \
          || ($(RM) $@; exit 1)

#*---------------------------------------------------------------------*/
#*    idx.json ...                                                     */
#*---------------------------------------------------------------------*/
idx.json: manual.html
	$(HOP) $(HOPFLAGS) $(EFLAGS) -- \
          ./doc.js "html-to-idx" . $^ manual-chapter*.html > $@ \
          || ($(RM) $@; exit 1)

#*---------------------------------------------------------------------*/
#*    idx.html ...                                                     */
#*---------------------------------------------------------------------*/
idx.html: idx.json
	$(HOP) $(HOPFLAGS) $(EFLAGS) -- \
          ./doc.js "compile-idx" $^ > $@ \
          || ($(RM) $@; exit 1)

#*---------------------------------------------------------------------*/
#*    html-idx.json ...                                                */
#*---------------------------------------------------------------------*/
html-idx.json: 
	$(HOP) $(HOPFLAGS) $(EFLAGS) -- \
          ./html.js $(HTML) > $@ \
          || ($(RM) $@; exit 1)

#*---------------------------------------------------------------------*/
#*    mdn-idx.json ...                                                 */
#*---------------------------------------------------------------------*/
mdn-idx.json:
	$(HOP) $(HOPFLAGS) $(EFLAGS) -- \
          ./mdn.js > $@ \
          || ($(RM) $@; exit 1)

#*---------------------------------------------------------------------*/
#*    node-idx.json ...                                                */
#*---------------------------------------------------------------------*/
node-idx.json: node.js
	$(HOP) $(HOPFLAGS) $(EFLAGS) -- \
          ./node.js > $@ \
          || ($(RM) $@; exit 1)

#*---------------------------------------------------------------------*/
#*    dependencies                                                     */
#*---------------------------------------------------------------------*/
download.html: license.md ../INSTALL.md debian.md homebrew.md
lang.html: _lang.md
manual.html: manual-toc.js ../manuals/bigloo.texi
bib.html: _bibtex.hop bigloo.bib
cross.html: ../arch/raspberry/README.cross.md \
  ../arch/android/README.cross.md

hss/markdown.css: ../node_modules/markdown/hss/markdown.hss
	cp $< $@

hss/texinfo.css: ../node_modules/texinfo/hss/texinfo.hss
	cp $< $@

hss/fontifier.css: ../node_modules/fontifier/hss/fontifier.hss
	cp $< $@

hss/doc.css: hss/doc.hss
	cp $< $@

favicon.png: ../share/icons/hop/favicon-16x16.png
	cp $< $@

LICENSE.academic: ../LICENSE.academic
	cp $< $@