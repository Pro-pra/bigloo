;*=====================================================================*/
;*    serrano/prgm/project/bigloo/api/alsa/src/Llib/music.scm          */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Sat Jun 25 06:55:51 2011                          */
;*    Last change :  Mon Jan 30 08:28:17 2012 (serrano)                */
;*    Copyright   :  2011-12 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    A (multimedia) music player.                                     */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __alsa_music
   
   (library multimedia)
   
   (import  __alsa_alsa
	    __alsa_pcm)

   (static  (class alsaportbuffer::alsabuffer
	       (port::input-port read-only)
	       (readsz::long read-only (default 8192))
	       (%inbuf::bstring read-only))
	    
	    (class alsammapbuffer::alsabuffer
	       (mmap::mmap read-only)))
	    
   (export  (class alsamusic::music
	       (inbuf::bstring read-only (default (make-string (*fx 512 1024))))
	       (outbuf::bstring read-only (default (make-string (*fx 5 1024))))
	       (pcm::alsa-snd-pcm read-only (default (instantiate::alsa-snd-pcm)))
	       (decoders::pair-nil read-only (default '()))
	       (mkthread::procedure read-only (default make-thread))
	       (%decoder (default #f))
	       (%buffer (default #f))
	       
	       (%playlist::pair-nil (default '()))
	       (%toseek::long (default -1))
	       (%aready::bool (default #t))
	       (%!aabort::bool (default #f))
	       (%amutex::mutex read-only (default (make-mutex)))
	       (%acondv::condvar read-only (default (make-condition-variable))))

	    (class alsabuffer
	       (url::bstring read-only)
	       ;; state is either empty:0, filled:1, full:2
	       (%!bstate::int (default 0))
	       (%eof::bool (default #f))
	       (%!babort::bool (default #f))
	       (%bcondv::condvar read-only (default (make-condition-variable)))
	       (%bmutex::mutex read-only (default (make-mutex)))
	       (%inlen::long read-only)
	       
	       (%inbufp::string read-only)
	       (%head::long (default 0))
	       (%!tail::long (default 0)))
	    
	    (class alsadecoder
	       (alsadecoder-init)
	       (mimetypes::pair-nil (default '()))
	       (buffer-time-near::int (default 500000))
	       (buffer-size-near-ratio::int (default 2))
	       (period-size-near-ratio::int (default 8))
	       ;; init: 0, playing: 1, pause: 2, stop: 3, ended: 4
	       (%!dstate::int (default 0))
	       (%!dpause::bool (default #f))
	       (%!dabort::bool (default #f))
	       (%!stop::bool (default #t))
	       (%!dseek::long (default -1))
	       (%dmutex::mutex read-only (default (make-mutex)))
	       (%dcondv::condvar read-only (default (make-condition-variable)))
	       (%doutcondv::condvar read-only (default (make-condition-variable))))
	    
	    (generic alsadecoder-init ::alsadecoder)
	    (generic alsadecoder-reset! ::alsadecoder)
	    (generic alsadecoder-close ::alsadecoder)
	    (generic alsadecoder-can-play-type? ::alsadecoder ::bstring)
	    (generic alsadecoder-decode ::alsadecoder ::alsamusic ::alsabuffer)
	    
	    (generic alsadecoder-position::long ::alsadecoder ::bstring)
	    (generic alsadecoder-info::long ::alsadecoder)
	    (generic alsadecoder-seek::long ::alsadecoder ::long)
	    (generic alsadecoder-volume-set! ::alsadecoder ::long)))

;*---------------------------------------------------------------------*/
;*    $compiler-debug ...                                              */
;*---------------------------------------------------------------------*/
(define-macro ($compiler-debug)
   (bigloo-compiler-debug))

;*---------------------------------------------------------------------*/
;*    debug                                                            */
;*---------------------------------------------------------------------*/
(define debug ($compiler-debug))

;*---------------------------------------------------------------------*/
;*    music-init ::alsamusic ...                                       */
;*---------------------------------------------------------------------*/
(define-method (music-init o::alsamusic)
   (with-access::alsamusic o (%amutex %status inbuf outbuf)
      (with-lock %amutex
	 (lambda ()
	    (cond
	       ((<fx (string-length outbuf) 1024)
		(raise (instantiate::&alsa-error
			  (proc "alsamusic")
			  (msg "outbuf must be at least 1024 bytes")
			  (obj (string-length inbuf)))))
	       ((<fx (string-length inbuf) (string-length outbuf))
		(raise (instantiate::&alsa-error
			  (proc "alsamusic")
			  (msg "inbuf length must be greater that outbuf length")
			  (obj (cons (string-length inbuf) (string-length outbuf) ))))))
	    (with-access::musicstatus %status (volume state)
	       (set! volume 100)
	       (set! state 'uninitialized))))))

;*---------------------------------------------------------------------*/
;*    music-close ::alsamusic ...                                      */
;*---------------------------------------------------------------------*/
(define-method (music-close o::alsamusic)
   (with-access::alsamusic o (pcm decoders %amutex)
      (with-lock %amutex
	 (lambda ()
	    (unless (eq? (alsa-snd-pcm-get-state pcm) 'disconnected))
	       (alsa-snd-pcm-close pcm)))))

;*---------------------------------------------------------------------*/
;*    music-closed? ::alsamusic ...                                    */
;*---------------------------------------------------------------------*/
(define-method (music-closed? o::alsamusic)
   (with-access::alsamusic o (%amutex pcm)
      (with-lock %amutex
	 (lambda ()
	    (eq? (alsa-snd-pcm-get-state pcm) 'disconnected)))))

;*---------------------------------------------------------------------*/
;*    music-reset! ::alsamusic ...                                     */
;*---------------------------------------------------------------------*/
(define-method (music-reset! o::alsamusic)
   (call-next-method))

;*---------------------------------------------------------------------*/
;*    music-playlist-get ::alsamusic ...                               */
;*---------------------------------------------------------------------*/
(define-method (music-playlist-get o::alsamusic)
   (with-access::alsamusic o (%playlist)
      %playlist))

;*---------------------------------------------------------------------*/
;*    music-playlist-add! ::alsamusic ...                              */
;*---------------------------------------------------------------------*/
(define-method (music-playlist-add! o::alsamusic s)
   (with-access::alsamusic o (%amutex %playlist %status)
      (with-lock %amutex
	 (lambda ()
	    (set! %playlist (append! %playlist (list s)))
	    (with-access::musicstatus %status (playlistid playlistlength)
	       (set! playlistid (+fx 1 playlistid))
	       (set! playlistlength (+fx 1 playlistlength)))))))

;*---------------------------------------------------------------------*/
;*    music-playlist-delete! ::alsamusic ...                           */
;*---------------------------------------------------------------------*/
(define-method (music-playlist-delete! o::alsamusic n)
   (with-access::alsamusic o (%amutex %playlist %status)
      (with-lock %amutex
	 (lambda ()
	    (with-access::musicstatus %status (playlistid playlistlength)
	       (when (and (>=fx n 0) (<fx n playlistlength))
		  (set! %playlist (remq! (list-ref %playlist n) %playlist))
		  (set! playlistid (+fx 1 playlistid))
		  (set! playlistlength (length %playlist))))))))

;*---------------------------------------------------------------------*/
;*    music-playlist-clear! ::alsamusic ...                            */
;*---------------------------------------------------------------------*/
(define-method (music-playlist-clear! o::alsamusic)
   (with-access::alsamusic o (%amutex %playlist %status)
      (with-lock %amutex
	 (lambda ()
	    (set! %playlist '())
	    (with-access::musicstatus %status (playlistlength song)
	       (set! song 0)
	       (set! playlistlength 0))))))

;*---------------------------------------------------------------------*/
;*    music-can-play-type? ::alsamusic ...                             */
;*---------------------------------------------------------------------*/
(define-method (music-can-play-type? o::alsamusic mimetype::bstring)
   (with-access::alsamusic o (decoders)
      (any (lambda (d) (alsadecoder-can-play-type? d mimetype)) decoders)))
   
;*---------------------------------------------------------------------*/
;*    music-seek ...                                                   */
;*---------------------------------------------------------------------*/
(define-method (music-seek o::alsamusic pos . song)
   (with-access::alsamusic o (%amutex %decoder %toseek)
      (with-lock %amutex
	 (lambda ()
	    (if (pair? song)
		(begin
		   (unless (integer? (car song))
		      (bigloo-type-error '|music-seek ::alsamusic| 'int (car song)))
		   (set! %toseek pos)
		   (music-play o song))
		(when (isa? %decoder alsadecoder)
		   (with-access::alsadecoder %decoder (%!dseek)
		      (set! %!dseek pos))))))))

;*---------------------------------------------------------------------*/
;*    music-play ::alsamusic ...                                       */
;*---------------------------------------------------------------------*/
(define-method (music-play o::alsamusic . s)
   
   (define (find-decoder o url)
      (with-access::alsamusic o (decoders)
	 (let ((mime (mime-type url)))
	    (find (lambda (d) (alsadecoder-can-play-type? d mime))
	       decoders))))
   
   (define (update-song-status! o n)
      (with-access::alsamusic o (%status onstate onvolume)
	 (with-access::musicstatus %status (state song songpos songid songlength playlistid volume)
	    (set! songpos 0)
	    (set! songlength 0)
	    (set! song n)
	    (set! songid (+fx (* 100 playlistid) n))
	    (set! state 'play)
	    (onstate o %status)
	    (onvolume o volume))))
   
   (define (pcm-init o)
      (with-access::alsamusic o (pcm)
	 (when (eq? (alsa-snd-pcm-get-state pcm) 'not-open)
	    (alsa-snd-pcm-open pcm))))

   (define (pcm-reset! o)
      (with-access::alsamusic o (pcm)
	 (let ((pcm-state (alsa-snd-pcm-get-state pcm)))
	    (when (memq pcm-state '(running prepared))
	       (alsa-snd-pcm-drop pcm)))
	 (alsa-snd-pcm-cleanup pcm)))

   (define (play-url-port o d::alsadecoder url::bstring playlist)
      (let ((ip (open-input-file url)))
	 (if (input-port? ip)
	     (with-access::alsamusic o (%amutex outbuf inbuf %buffer onevent
					  mkthread %status)
		(let ((buffer (instantiate::alsaportbuffer
				 (url url)
				 (port ip)
				 (%inlen (string-length inbuf))
				 (%inbuf inbuf)
				 (%inbufp inbuf))))
		   (set! %buffer buffer)
		   (mutex-unlock! %amutex)
		   (thread-start!
		      (mkthread
			 (lambda ()
			    (unwind-protect
			       (alsabuffer-fill! buffer o)
			       (close-input-port ip)))
			 "alsamusic-buffer"))
		   (when playlist
		      (with-access::musicstatus %status (playlistid)
			 (onevent o 'playlist playlistid)))
		   (alsadecoder-decode d o buffer)
		   (alsadecoder-reset! d)))
	     (with-access::alsamusic o (onerror %amutex)
		(mutex-unlock! %amutex)
		(onerror o
		   (instantiate::&io-port-error
		      (proc "music-play")
		      (msg "Cannot open")
		      (obj url)))))))

   (define (play-url-mmap o d::alsadecoder url::bstring playlist)
      (let ((mmap (open-mmap url :read #t :write #f)))
	 (if (mmap? mmap)
	     (with-access::alsamusic o (%amutex outbuf inbuf %buffer onevent
					  %status)
		(let ((buffer (instantiate::alsammapbuffer
				 (url url)
				 (mmap mmap)
				 (%inlen (mmap-length mmap))
				 (%inbufp (mmap->string mmap)))))
		   (set! %buffer buffer)
		   (mutex-unlock! %amutex)
		   (alsabuffer-fill! buffer o)
		   (when playlist
		      (with-access::musicstatus %status (playlistid)
			 (onevent o 'playlist playlistid)))
		   (alsadecoder-decode d o buffer)
		   (alsadecoder-reset! d)
		   (close-mmap mmap)))
	     (with-access::alsamusic o (onerror %amutex)
		(mutex-unlock! %amutex)
		(onerror o
		   (instantiate::&io-port-error
		      (proc "music-play")
		      (msg "Cannot open")
		      (obj url)))))))
   
   (define (play-url o d::alsadecoder url::bstring playlist)
      (cond
	 ((file-exists? url) (play-url-mmap o d url playlist))
	 (else (play-url-port o d url playlist))))
   
   (define (play-urls urls n)
      (with-access::alsamusic o (%amutex %!aabort onerror %decoder %toseek)
	 (let loop ((l urls)
		    (n n))
	    (unless %!aabort
	       (when (pair? l)
		  (let* ((url (car l))
			 (decoder (find-decoder o url)))
		     (if decoder
			 (with-access::alsadecoder decoder (%!dseek)
			    (set! %!dseek %toseek)
			    (set! %toseek -1)
			    (set! %decoder decoder)
			    (update-song-status! o n)
			    (play-url o decoder url (and (eq? l urls) urls))
			    (mutex-lock! %amutex)
			    (loop (cdr l) (+fx 1 n)))
			 (begin
			    (mutex-unlock! %amutex)
			    (onerror o (format "Illegal format \"~a\"" url))
			    (mutex-lock! %amutex)
			    (loop (cdr l) (+fx n 1))))))))))

   (define (play-playlist n)
      ;; start playing the playlist
      (with-access::alsamusic o (%playlist %aready)
	 (let ((playlist %playlist))
	    (when (and (>=fx n 0) (<fx n (length playlist)))
	       ;; init alsa pcm
	       (pcm-init o)
	       ;; wait the the music player to be ready
	       (alsamusic-wait-ready! o)
	       (set! %aready #f)
	       ;; play the list of urls
	       (play-urls (list-tail playlist n) n)))))

   (define (resume-from-pause o)
      (with-access::alsamusic o (%decoder)
	 (when (isa? %decoder alsadecoder)
	    (with-access::alsadecoder %decoder (%dmutex %dcondv %!dpause)
	       (mutex-lock! %dmutex)
	       (when %!dpause
		  (set! %!dpause #f)
		  (condition-variable-signal! %dcondv))
	       (mutex-unlock! %dmutex)
	       #t))))
   
   (with-access::alsamusic o (%amutex %acondv %decoder %buffer %aready %status)
      (with-lock %amutex
	 (lambda ()
	    (unwind-protect
	       (cond
		  ((pair? s)
		   ;; play the playing from a user index
		   (unless (integer? (car s))
		      (bigloo-type-error "music-play ::alsamusic" 'int (car s)))
		   (play-playlist (car s)))
		  ((resume-from-pause o)
		   #unspecified)
		  (else
		   ;; play the playlist from the current position
		   (with-access::musicstatus %status (song)
		      (play-playlist song))))
	       (begin
		  ;; reset the player state
		  (set! %aready #t)
		  (set! %buffer #f)
		  (set! %decoder #f)
		  (pcm-reset! o)
		  ;; signal if someone waiting for the music player
		  (condition-variable-signal! %acondv)))))))

;*---------------------------------------------------------------------*/
;*    alsamusic-state ...                                              */
;*---------------------------------------------------------------------*/
(define (alsamusic-state::symbol o::alsamusic)
   ;; %amutex already locked
   (with-access::alsamusic o (%decoder)
      (if (isa? %decoder alsadecoder)
	  (with-access::alsadecoder %decoder (%!dstate)
	     (case %!dstate
		((0) 'init)
		((1) 'play)
		((2) 'pause)
		((3) 'stop)
		((4) 'ended)
		(else 'undefined)))
	  'init)))

;*---------------------------------------------------------------------*/
;*    music-stop ::alsamusic ...                                       */
;*---------------------------------------------------------------------*/
(define-method (music-stop o::alsamusic)
   (with-access::alsamusic o (%amutex onstate %status)
      (with-lock %amutex
	 (lambda ()
	    (alsamusic-wait-ready! o)))))

;*---------------------------------------------------------------------*/
;*    alsamusic-wait-ready! ...                                        */
;*---------------------------------------------------------------------*/
(define (alsamusic-wait-ready! o::alsamusic)
   ;; %amutex already locked
   (with-access::alsamusic o (%decoder %buffer)
      (when (isa? %decoder alsadecoder)
	 (alsadecoder-abort! %decoder))
      (when (isa? %buffer alsabuffer)
	 (alsabuffer-abort! %buffer))
      (with-access::alsamusic o (%aready %!aabort %acondv %amutex)
	 (unless %aready
	    (set! %!aabort #t)
	    (let loop ()
	       (unless %aready
		  ;; keep waiting
		  (condition-variable-wait! %acondv %amutex)
		  (loop))))
	 (set! %aready #t)
	 (set! %!aabort #f))))

;*---------------------------------------------------------------------*/
;*    alsabuffer-abort! ...                                            */
;*---------------------------------------------------------------------*/
(define (alsabuffer-abort! b::alsabuffer)
   (with-access::alsabuffer b (%bmutex %bcondv %!babort)
      (mutex-lock! %bmutex)
      (set! %!babort #t)
      (condition-variable-broadcast! %bcondv)
      (mutex-unlock! %bmutex)))

;*---------------------------------------------------------------------*/
;*    alsadecoder-abort! ...                                           */
;*---------------------------------------------------------------------*/
(define (alsadecoder-abort! d::alsadecoder)
   (with-access::alsadecoder d (%!dabort %!dpause %dmutex %dcondv)
      (mutex-lock! %dmutex)
      (set! %!dpause #f)
      (set! %!dabort #t)
      (condition-variable-signal! %dcondv)
      (mutex-unlock! %dmutex)))

;*---------------------------------------------------------------------*/
;*    music-pause ...                                                  */
;*---------------------------------------------------------------------*/
(define-method (music-pause o::alsamusic)
   (with-access::alsamusic o (%amutex %decoder)
      (with-lock %amutex
	 (lambda ()
	    (when (isa? %decoder alsadecoder)
	       (alsadecoder-pause %decoder))))))

;*---------------------------------------------------------------------*/
;*    alsadecoder-pause ...                                            */
;*---------------------------------------------------------------------*/
(define (alsadecoder-pause d::alsadecoder)
   (with-access::alsadecoder d (%dmutex %dcondv %!dpause)
      (mutex-lock! %dmutex)
      (if %!dpause
	  (begin
	     (set! %!dpause #f)
	     (condition-variable-signal! %dcondv))
	  (set! %!dpause #t))
      (mutex-unlock! %dmutex)))

;*---------------------------------------------------------------------*/
;*    alsabuffer-fill! ...                                             */
;*---------------------------------------------------------------------*/
(define-generic (alsabuffer-fill! buffer::alsabuffer o::alsamusic))
   
;*---------------------------------------------------------------------*/
;*    alsabuffer-fill! ...                                             */
;*---------------------------------------------------------------------*/
(define-method (alsabuffer-fill! buffer::alsaportbuffer o::alsamusic)
   (with-access::alsaportbuffer buffer (%bmutex %bcondv %!bstate %!babort %head %!tail %inbuf %inlen %eof readsz port url)
      
      (define inlen %inlen)
      
      (define (available)
	 (cond
	    ((>fx %head %!tail) (-fx %head %!tail))
	    ((<fx %head %!tail) (+fx (-fx inlen (-fx %!tail 1)) %head))
	    (else inlen)))

      (define (empty-state?)
	 (and (=fx %!bstate 0) (>fx (*fx (available) 4) inlen)))
      
      (define (fill sz)
	 (let* ((sz (minfx sz readsz))
		(i (read-fill-string! %inbuf %head sz port)))
	    (if (eof-object? i)
		(with-access::alsamusic o (onevent)
		   (when (>fx debug 0)
		      (tprint "fill.2a, set eof-filled (bs=1)"))
;* 		   (when (=fx %!bstate 0)                              */
;* 		      (mutex-lock! %bmutex)                            */
;* 		      (set! %!bstate 1)                                */
;* 		      (mutex-unlock! %bmutex))                         */
		   (set! %eof #t)
 		   (onevent o 'loaded url))
		(let ((nhead (+fx %head i)))
		   (if (=fx nhead inlen)
		       (set! %head 0)
		       (set! %head nhead))
		   (cond
		      ((=fx %head %!tail)
		       ;; set state full
		       (mutex-lock! %bmutex)
		       (when (>fx debug 0)
			  (tprint "fill.2b, set full (bs=2)"))
		       (set! %!bstate 2)
		       (condition-variable-broadcast! %bcondv)
		       (mutex-unlock! %bmutex))
		      ((empty-state?)
		       ;; set state filled
		       (mutex-lock! %bmutex)
		       (when (>fx debug 0)
			  (tprint "fill.2c, set filled (bs=1)"))
		       (set! %!bstate 1)
		       (condition-variable-broadcast! %bcondv)
		       (mutex-unlock! %bmutex)))))))

      (let loop ()
	 (when (>fx debug 1)
	    (tprint "fill.1 %!bstate=" %!bstate
	       " tl=" %!tail " hd=" %head " eof=" %eof))
	 (cond
	    ((or %eof %!babort)
	     (mutex-lock! %bmutex)
	     (condition-variable-broadcast! %bcondv)
	     (mutex-unlock! %bmutex))
	    ((=fx %!bstate 2)
	     ;; buffer full, wait to be flushed
	     (mutex-lock! %bmutex)
	     (when (=fx %!bstate 2)
		;; a kind of double check locking, correct, is
		;; ptr read/write are atomic
		(condition-variable-wait! %bcondv %bmutex))
	     (mutex-unlock! %bmutex)
	     (loop))
	    ((<fx %head %!tail)
	     ;; free space before the tail
	     (fill (-fx %!tail %head))
	     (loop))
	    (else
	     ;; free space after the tail (>=fx %head %!tail)
	     (fill (-fx inlen %head))
	     (loop))))))

;*---------------------------------------------------------------------*/
;*    alsabuffer-fill! ...                                             */
;*---------------------------------------------------------------------*/
(define-method (alsabuffer-fill! buffer::alsammapbuffer o::alsamusic)
   (with-access::alsammapbuffer buffer (%!bstate %head %inbufp %eof mmap url)
      (set! %inbufp (mmap->string mmap))
      (set! %head 0)
      (set! %!bstate 1)
      (set! %eof #t)
      (with-access::alsamusic o (onevent)
	 (onevent o 'loaded url))))

;*---------------------------------------------------------------------*/
;*    alsadecoder-decode ::alsadecoder ...                             */
;*---------------------------------------------------------------------*/
(define-generic (alsadecoder-decode d::alsadecoder o::alsamusic b::alsabuffer))

;*---------------------------------------------------------------------*/
;*    music-volume-get ::alsamusic ...                                 */
;*---------------------------------------------------------------------*/
(define-method (music-volume-get o::alsamusic)
   (with-access::alsamusic o (%status)
      (with-access::musicstatus %status (volume)
	 volume)))

;*---------------------------------------------------------------------*/
;*    music-volume-set! ::alsamusic ...                                */
;*---------------------------------------------------------------------*/
(define-method (music-volume-set! o::alsamusic vol)
   (with-access::alsamusic o (decoders %status onvolume)
      (for-each (lambda (d) (alsadecoder-volume-set! d vol)) decoders)
      (with-access::musicstatus %status (volume)
	 (set! volume vol)
	 (onvolume o vol))))
   
;*---------------------------------------------------------------------*/
;*    alsadecoder-init ::alsadecoder ...                               */
;*---------------------------------------------------------------------*/
(define-generic (alsadecoder-init o::alsadecoder)
   o)

;*---------------------------------------------------------------------*/
;*    alsadecoder-reset! ...                                           */
;*---------------------------------------------------------------------*/
(define-generic (alsadecoder-reset! o::alsadecoder)
   (with-access::alsadecoder o (%dmutex %!dpause %!dabort)
      (mutex-lock! %dmutex)
      (set! %!dpause #f)
      (set! %!dabort #f)
      (mutex-unlock! %dmutex)
      #f))

;*---------------------------------------------------------------------*/
;*    alsadecoder-close ::alsadecoder ...                              */
;*---------------------------------------------------------------------*/
(define-generic (alsadecoder-close o::alsadecoder))
   
;*---------------------------------------------------------------------*/
;*    alsadecoder-can-play-type? ...                                   */
;*---------------------------------------------------------------------*/
(define-generic (alsadecoder-can-play-type? o::alsadecoder mime::bstring)
   (with-access::alsadecoder o (mimetypes)
      (member mime mimetypes)))

;*---------------------------------------------------------------------*/
;*    alsadecoder-position ::alsadecoder ...                           */
;*---------------------------------------------------------------------*/
(define-generic (alsadecoder-position o::alsadecoder inbuf))

;*---------------------------------------------------------------------*/
;*    alsadecoder-info ::alsadecoder ...                               */
;*---------------------------------------------------------------------*/
(define-generic (alsadecoder-info o::alsadecoder))

;*---------------------------------------------------------------------*/
;*    alsadecoder-seek ::alsadecoder ...                               */
;*---------------------------------------------------------------------*/
(define-generic (alsadecoder-seek o::alsadecoder ms::long))

;*---------------------------------------------------------------------*/
;*    alsadecoder-volume-set! ::alsadecoder ...                        */
;*---------------------------------------------------------------------*/
(define-generic (alsadecoder-volume-set! o::alsadecoder v::long))

;*---------------------------------------------------------------------*/
;*    mime-type ...                                                    */
;*---------------------------------------------------------------------*/
(define (mime-type path)
   
   (define (mime-type-file path)
      (cond
	 ((string-suffix? ".mp3" path) "audio/mpeg")
	 ((string-suffix? ".ogg" path) "application/ogg")
	 ((string-suffix? ".flac" path) "application/x-flac")
	 ((string-suffix? ".wav" path) "audio/x-wav")
	 ((string-suffix? ".swf" path) "application/x-shockwave-flash")
	 ((string-suffix? ".swfl" path) "application/x-shockwave-flash")
	 (else "audio/binary")))
   
   (if (and (string-prefix? "http" path)
	    (or (string-prefix? "http://" path)
		(string-prefix? "https://" path)))
       (let ((i (string-index-right path #\?)))
	  (if i
	      (mime-type (substring path 6 i))
	      (mime-type-file path)))
       (mime-type-file path)))
