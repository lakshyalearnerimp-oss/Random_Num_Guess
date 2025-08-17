;; File: random-number-generator.clar
;; Purpose: Pseudo-randomness for games using commit–reveal + previous block hash.
;; NOTE: This is NOT cryptographically secure randomness. For fair, high-stakes games,
;;       use an oracle or a multi-party commit–reveal with economic penalties.

(define-constant ERR-NO-COMMIT (err u100))
(define-constant ERR-SAME-BLOCK (err u101))
(define-constant ERR-BAD-REVEAL (err u102))

;; How long (in blocks) a commit stays valid (optional guard).
(define-constant COMMIT_TTL u144) ;; ~24h on Stacks mainnet (~10 min blocks)

(define-data-var commits
  (map principal { commit-hash: (buff 32), committed-at: uint })
  (map)
)

;; --- Helpers ---------------------------------------------------------------

(define-read-only (get-previous-header-hash)
  (let (
        (h-now block-height)
        (h-prev (if (> block-height u0) (- block-height u1) u0))
       )
    ;; header-hash is an optional buff(32); unwrap-panic aborts if not found.
    (unwrap-panic (get-block-info? header-hash h-prev))
  )
)

(define-private (mix (a (buff 32)) (b (buff 32)))
  ;; Mix two 32-byte values into a new 32-byte hash
  (sha256 (concat a b))
)

;; Convert a 32-byte hash into an *indexable* 32-byte stream by salting with a counter.
(define-private (derive (seed (buff 32)) (ctr uint))
  (sha256 (concat seed (sha256 (concat (to-uint ctr) seed))))
)

;; Derive a bounded index from a seed and counter.
;; Because Clarity lacks a direct buff->uint cast across the full 32 bytes portably,
;; we fold down to 16 bits deterministically, then mod.
(define-read-only (rand-index (seed (buff 32)) (upper-bound uint) (ctr uint))
  (let (
        (s (derive seed ctr))
        ;; Take first two bytes and form a uint: b0 * 256 + b1
        (b0 (buff-at s u0))           ;; (buff 1)
        (b1 (buff-at s u1))           ;; (buff 1)
        (u0' (to-uint (buff-to-int b0))) ;; safe because 1-byte
        (u1' (to-uint (buff-to-int b1)))
        (num (+ (* u0' u256) u1'))
       )
    (if (is-eq upper-bound u0)
        u0
        (mod num upper-bound)
    )
  )
)

;; --- Public API ------------------------------------------------------------

;; Step 1: Commit a secret (client computes sha256(secret) off-chain and passes it here)
(define-public (commit (commit-hash (buff 32)))
  (begin
    (map-set commits {principal: tx-sender} {commit-hash: commit-hash, committed-at: block-height})
    (ok true)
  )
)

;; Step 2: Reveal the secret to get a pseudo-random 32-byte seed.
;; Returns (buff 32) that you can use directly or feed into `rand-index`.
(define-public (reveal (secret (buff 32)))
  (let (
        (entry (map-get? commits {principal: tx-sender}))
       )
    (if (is-none entry)
        ERR-NO-COMMIT
        (let (
              (e (unwrap-panic entry))
              (expected (get commit-hash e))
              (committed-at (get committed-at e))
              (now block-height)
             )
          ;; Prevent same-block commit+reveal (forces inclusion in different block)
          (if (is-eq now committed-at)
              ERR-SAME-BLOCK
              (if (is-eq (sha256 secret) expected)
                  (let (
                        ;; Optional TTL guard: uncomment to enforce expiry.
                        ;; (_ (asserts! (<= (- now committed-at) COMMIT_TTL) (err u103)))
                        (prev-hash (get-previous-header-hash))
                        (seed (mix (sha256 secret) prev-hash))
                       )
                    ;; Clear commit to avoid reuse
                    (begin
                      (map-delete commits {principal: tx-sender})
                      (ok seed)
                    )
                  )
                  ERR-BAD-REVEAL
              )
          )
        )
    )
  )
)

;; Convenience: produce a bounded index in [0, upper-bound)
;; You must pass the `seed` returned by `reveal` and a counter to derive multiple values.
(define-read-only (rand-in-range (seed (buff 32)) (upper-bound uint) (counter uint))
  (rand-index seed upper-bound counter)
)
