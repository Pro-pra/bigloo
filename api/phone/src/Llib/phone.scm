;*=====================================================================*/
;*    serrano/prgm/project/bigloo/api/phone/src/Llib/phone.scm         */
;*    -------------------------------------------------------------    */
;*    Author      :  Manuel Serrano                                    */
;*    Creation    :  Sat Jul 30 14:07:08 2005                          */
;*    Last change :  Fri Dec 13 12:12:47 2013 (serrano)                */
;*    Copyright   :  2005-20 Manuel Serrano                            */
;*    -------------------------------------------------------------    */
;*    Generic phone API                                                */
;*=====================================================================*/

;*---------------------------------------------------------------------*/
;*    The module                                                       */
;*---------------------------------------------------------------------*/
(module __phone

   (option (set! *dlopen-init-gc* #t))
   
   (export (abstract-class phone
	      (phone-init)
	      (sensor-ttl::int (default 100)))
	   
	   (generic phone-init ::phone)

	   (generic phone-reboot ::phone)
	   
	   (generic phone-locales::pair-nil ::phone)
	   (generic phone-current-locale ::phone)
	   (generic phone-current-locale-set! ::phone ::obj)
	   
	   (generic phone-vibrate ::phone ::obj ::obj)
	   (generic phone-vibrate-stop ::phone)

	   (generic phone-sensor-list ::phone)
	   (generic phone-sensor ::phone ::symbol #!optional delay)

	   (generic phone-sms-send ::phone ::bstring ::bstring)

	   (generic phone-contact::pair-nil ::phone #!optional filter)
	   (generic phone-contact-add! ::phone ::obj)
	   (generic phone-contact-update! ::phone ::obj)
	   (generic phone-contact-remove! ::phone ::obj)
	   
	   (generic phone-call-log::pair-nil ::phone #!optional num)
	   (generic phone-call-info::pair-nil ::phone)
	   (generic phone-call-dial ::phone ::bstring)
	   (generic phone-call-start ::phone ::bstring #!optional window)
	   (generic phone-call-stop ::phone)))

;*---------------------------------------------------------------------*/
;*    Generic functions                                                */
;*---------------------------------------------------------------------*/
(define-generic (phone-init p::phone))

;*---------------------------------------------------------------------*/
;*    phone-reboot ::phone ...                                         */
;*---------------------------------------------------------------------*/
(define-generic (phone-reboot p::phone))

;*---------------------------------------------------------------------*/
;*    phone-locales ...                                                */
;*---------------------------------------------------------------------*/
(define-generic (phone-locales p::phone))
(define-generic (phone-current-locale p::phone))
(define-generic (phone-current-locale-set! p::phone locale::obj))

;*---------------------------------------------------------------------*/
;*    vibrate                                                          */
;*---------------------------------------------------------------------*/
(define-generic (phone-vibrate p::phone vibration::obj repeat::obj))
(define-generic (phone-vibrate-stop p::phone))

;*---------------------------------------------------------------------*/
;*    sensors                                                          */
;*---------------------------------------------------------------------*/
(define-generic (phone-sensor-list p::phone)
   '())
(define-generic (phone-sensor p::phone t::symbol #!optional delay))

;*---------------------------------------------------------------------*/
;*    sms                                                              */
;*---------------------------------------------------------------------*/
(define-generic (phone-sms-send p::phone no::bstring message::bstring))

;*---------------------------------------------------------------------*/
;*    phone-contact ::phone ...                                        */
;*---------------------------------------------------------------------*/
(define-generic (phone-contact p::phone #!optional filter))
(define-generic (phone-contact-add! p::phone o::obj))
(define-generic (phone-contact-update! p::phone o::obj))
(define-generic (phone-contact-remove! p::phone o::obj))

;*---------------------------------------------------------------------*/
;*    telephony                                                        */
;*---------------------------------------------------------------------*/
(define-generic (phone-call-log p::phone #!optional num))
(define-generic (phone-call-info p::phone))
(define-generic (phone-call-dial p::phone num))
(define-generic (phone-call-start p::phone num #!optional window))
(define-generic (phone-call-stop p::phone))
   
