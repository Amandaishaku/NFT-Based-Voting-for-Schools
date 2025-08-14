;; title: NFT-based-Voting
;; version: 1.0.0
;; summary: NFT-based voting system for school policies where parents vote using NFTs
;; description: A decentralized voting platform allowing parents to vote on school policies using NFTs as voting tokens



(define-non-fungible-token school-voter-nft uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-proposal-not-found (err u102))
(define-constant err-voting-ended (err u103))
(define-constant err-already-voted (err u104))
(define-constant err-invalid-vote (err u105))
(define-constant err-proposal-active (err u106))
(define-constant err-insufficient-votes (err u107))
(define-constant err-self-delegation (err u108))
(define-constant err-delegate-not-found (err u109))
(define-constant err-delegation-loop (err u110))

(define-data-var last-token-id uint u0)
(define-data-var proposal-counter uint u0)

(define-map token-count principal uint)
(define-map proposals 
  uint 
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    creator: principal,
    start-block: uint,
    end-block: uint,
    yes-votes: uint,
    no-votes: uint,
    status: (string-ascii 20)
  }
)

(define-map votes 
  {proposal-id: uint, voter: principal} 
  {vote: bool, token-id: uint}
)

(define-map voter-info
  principal
  {
    name: (string-ascii 50),
    school: (string-ascii 50),
    registered-block: uint
  }
)

(define-map delegations
  principal
  {
    delegate: principal,
    delegated-block: uint
  }
)

(define-map delegation-power
  principal
  uint
)

(define-public (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-public (get-token-uri (token-id uint))
  (ok none)
)

(define-public (get-owner (token-id uint))
  (ok (nft-get-owner? school-voter-nft token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (nft-transfer? school-voter-nft token-id sender recipient)
  )
)

(define-public (mint-voter-nft (recipient principal) (name (string-ascii 50)) (school (string-ascii 50)))
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (nft-mint? school-voter-nft token-id recipient))
    (var-set last-token-id token-id)
    (map-set token-count recipient (+ (default-to u0 (map-get? token-count recipient)) u1))
    (map-set voter-info recipient {
      name: name,
      school: school,
      registered-block: stacks-block-height
    })
    (ok token-id)
  )
)

(define-public (create-proposal 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (voting-duration uint)
)
  (let
    (
      (proposal-id (+ (var-get proposal-counter) u1))
      (start-block stacks-block-height)
      (end-block (+ stacks-block-height voting-duration))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set proposals proposal-id {
      title: title,
      description: description,
      creator: tx-sender,
      start-block: start-block,
      end-block: end-block,
      yes-votes: u0,
      no-votes: u0,
      status: "active"
    })
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote bool) (token-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
      (voter tx-sender)
      (current-block stacks-block-height)
      (vote-power (+ u1 (default-to u0 (map-get? delegation-power voter))))
    )
    (asserts! (is-eq (some voter) (nft-get-owner? school-voter-nft token-id)) err-not-token-owner)
    (asserts! (>= current-block (get start-block proposal)) err-voting-ended)
    (asserts! (<= current-block (get end-block proposal)) err-voting-ended)
    (asserts! (is-eq (get status proposal) "active") err-voting-ended)
    (asserts! (is-none (map-get? votes {proposal-id: proposal-id, voter: voter})) err-already-voted)
    
    (map-set votes {proposal-id: proposal-id, voter: voter} {vote: vote, token-id: token-id})
    
    (if vote
      (map-set proposals proposal-id (merge proposal {yes-votes: (+ (get yes-votes proposal) vote-power)}))
      (map-set proposals proposal-id (merge proposal {no-votes: (+ (get no-votes proposal) vote-power)}))
    )
    (ok true)
  )
)

(define-public (finalize-proposal (proposal-id uint))
  (let
    (
      (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
      (current-block stacks-block-height)
      (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> current-block (get end-block proposal)) err-proposal-active)
    (asserts! (is-eq (get status proposal) "active") err-voting-ended)
    
    (let
      (
        (result (if (> (get yes-votes proposal) (get no-votes proposal)) "passed" "rejected"))
      )
      (map-set proposals proposal-id (merge proposal {status: result}))
      (ok result)
    )
  )
)

(define-public (bulk-mint-nfts (recipients (list 50 {recipient: principal, name: (string-ascii 50), school: (string-ascii 50)})))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map mint-single-nft recipients))
  )
)

(define-private (mint-single-nft (data {recipient: principal, name: (string-ascii 50), school: (string-ascii 50)}))
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
      (recipient (get recipient data))
      (name (get name data))
      (school (get school data))
    )
    (unwrap-panic (nft-mint? school-voter-nft token-id recipient))
    (var-set last-token-id token-id)
    (map-set token-count recipient (+ (default-to u0 (map-get? token-count recipient)) u1))
    (map-set voter-info recipient {
      name: name,
      school: school,
      registered-block: stacks-block-height
    })
    token-id
  )
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
  (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-voter-info (voter principal))
  (map-get? voter-info voter)
)

(define-read-only (get-voter-token-count (voter principal))
  (default-to u0 (map-get? token-count voter))
)

(define-read-only (get-proposal-stats (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal 
    (ok {
      total-votes: (+ (get yes-votes proposal) (get no-votes proposal)),
      yes-percentage: (if (> (+ (get yes-votes proposal) (get no-votes proposal)) u0)
                        (/ (* (get yes-votes proposal) u100) (+ (get yes-votes proposal) (get no-votes proposal)))
                        u0),
      status: (get status proposal),
      blocks-remaining: (if (> (get end-block proposal) stacks-block-height)
                          (- (get end-block proposal) stacks-block-height)
                          u0)
    })
    err-proposal-not-found
  )
)

(define-read-only (get-active-proposals)
  (ok (filter is-proposal-active (map get-proposal-id (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10))))
)

(define-private (get-proposal-id (id uint))
  id
)

(define-private (is-proposal-active (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal (and 
               (is-eq (get status proposal) "active")
               (<= stacks-block-height (get end-block proposal))
               (>= stacks-block-height (get start-block proposal)))
    false
  )
)

(define-read-only (can-vote (proposal-id uint) (voter principal))
  (let
    (
      (proposal (map-get? proposals proposal-id))
      (has-tokens (> (get-voter-token-count voter) u0))
      (current-block stacks-block-height)
    )
    (match proposal
      prop (ok (and 
                 has-tokens
                 (is-eq (get status prop) "active")
                 (>= current-block (get start-block prop))
                 (<= current-block (get end-block prop))
                 (is-none (map-get? votes {proposal-id: proposal-id, voter: voter}))))
      err-proposal-not-found
    )
  )
)

(define-public (delegate-vote (delegate principal))
  (let
    (
      (delegator tx-sender)
      (current-power (default-to u0 (map-get? delegation-power delegate)))
    )
    (asserts! (not (is-eq delegator delegate)) err-self-delegation)
    (asserts! (> (get-voter-token-count delegator) u0) err-not-token-owner)
    (asserts! (is-some (map-get? voter-info delegate)) err-delegate-not-found)
    
    (match (map-get? delegations delegator)
      existing-delegation 
        (let
          (
            (old-delegate (get delegate existing-delegation))
            (old-power (default-to u0 (map-get? delegation-power old-delegate)))
          )
          (if (> old-power u0)
            (map-set delegation-power old-delegate (- old-power u1))
            true
          )
        )
      true
    )
    
    (map-set delegations delegator {
      delegate: delegate,
      delegated-block: stacks-block-height
    })
    (map-set delegation-power delegate (+ current-power u1))
    (ok true)
  )
)

(define-public (revoke-delegation)
  (let
    (
      (delegator tx-sender)
      (delegation (unwrap! (map-get? delegations delegator) err-delegate-not-found))
      (delegate (get delegate delegation))
      (current-power (default-to u0 (map-get? delegation-power delegate)))
    )
    (map-delete delegations delegator)
    (if (> current-power u0)
      (map-set delegation-power delegate (- current-power u1))
      true
    )
    (ok true)
  )
)



(define-read-only (get-delegation (delegator principal))
  (map-get? delegations delegator)
)

(define-read-only (get-delegation-power (delegate principal))
  (default-to u0 (map-get? delegation-power delegate))
)

(define-read-only (get-voting-power (voter principal))
  (+ (get-voter-token-count voter) (get-delegation-power voter))
)

(define-read-only (get-contract-stats)
  (ok {
    total-nfts-minted: (var-get last-token-id),
    total-proposals: (var-get proposal-counter),
    contract-owner: contract-owner
  })
)
