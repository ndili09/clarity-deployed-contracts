;; This is a boilerplate contract for a proposal 


(impl-trait 'SPX9XMC02T56N9PRXV4AM9TS88MMQ6A1Z3375MHD.proposal-trait.proposal-trait)

(define-constant MICRO (pow u10 u2))
(define-constant STXMICRO (pow u10 u6))

(define-public (execute (sender principal))
	(begin

    

		(print {event: "execute", sender: sender})

		(ok true)
	)
)
  