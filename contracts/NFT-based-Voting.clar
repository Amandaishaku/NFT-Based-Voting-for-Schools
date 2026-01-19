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
(define-constant err-quorum-not-met (err u111))
(define-constant err-invalid-quorum (err u112))
(define-constant err-contract-paused (err u113))
(define-constant err-invalid-tier (err u114))

(define-data-var last-token-id uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var default-quorum-percentage uint u25)
(define-data-var contract-paused bool false)

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
    status: (string-ascii 20),
    quorum-percentage: uint,
    total-eligible-voters: uint
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

(define-map voter-reputation
  principal
  {
    total-votes-cast: uint,
    proposals-created-voted: uint,
    consecutive-votes: uint,
    last-vote-proposal: uint,
    reputation-points: uint
  }
)

(define-map reputation-tiers
  uint
  {
    tier-name: (string-ascii 20),
    min-points: uint,
    vote-weight-bonus: uint
  }
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
      (eligible-voters (var-get last-token-id))
    )
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set proposals proposal-id {
      title: title,
      description: description,
      creator: tx-sender,
      start-block: start-block,
      end-block: end-block,
      yes-votes: u0,
      no-votes: u0,
      status: "active",
      quorum-percentage: (var-get default-quorum-percentage),
      total-eligible-voters: eligible-voters
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
    (asserts! (not (var-get contract-paused)) err-contract-paused)
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
      (required-votes (/ (* (get total-eligible-voters proposal) (get quorum-percentage proposal)) u100))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> current-block (get end-block proposal)) err-proposal-active)
    (asserts! (is-eq (get status proposal) "active") err-voting-ended)
    (asserts! (>= total-votes required-votes) err-quorum-not-met)
    
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
    (let
      (
        (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
        (required-votes (/ (* (get total-eligible-voters proposal) (get quorum-percentage proposal)) u100))
      )
      (ok {
        total-votes: total-votes,
        yes-percentage: (if (> total-votes u0)
                          (/ (* (get yes-votes proposal) u100) total-votes)
                          u0),
        status: (get status proposal),
        blocks-remaining: (if (> (get end-block proposal) stacks-block-height)
                            (- (get end-block proposal) stacks-block-height)
                            u0),
        quorum-percentage: (get quorum-percentage proposal),
        required-votes: required-votes,
        quorum-met: (>= total-votes required-votes),
        participation-rate: (if (> (get total-eligible-voters proposal) u0)
                              (/ (* total-votes u100) (get total-eligible-voters proposal))
                              u0)
      })
    )
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
    (asserts! (not (var-get contract-paused)) err-contract-paused)
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

(define-public (set-default-quorum (percentage uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= percentage u100) err-invalid-quorum)
    (asserts! (>= percentage u1) err-invalid-quorum)
    (var-set default-quorum-percentage percentage)
    (ok true)
  )
)

(define-public (create-proposal-with-quorum
  (title (string-ascii 100))
  (description (string-ascii 500))
  (voting-duration uint)
  (quorum-percentage uint)
)
  (let
    (
      (proposal-id (+ (var-get proposal-counter) u1))
      (start-block stacks-block-height)
      (end-block (+ stacks-block-height voting-duration))
      (eligible-voters (var-get last-token-id))
    )
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= quorum-percentage u100) err-invalid-quorum)
    (asserts! (>= quorum-percentage u1) err-invalid-quorum)
    (map-set proposals proposal-id {
      title: title,
      description: description,
      creator: tx-sender,
      start-block: start-block,
      end-block: end-block,
      yes-votes: u0,
      no-votes: u0,
      status: "active",
      quorum-percentage: quorum-percentage,
      total-eligible-voters: eligible-voters
    })
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
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
    contract-owner: contract-owner,
    default-quorum-percentage: (var-get default-quorum-percentage)
  })
)

(define-read-only (get-quorum-info (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal
    (let
      (
        (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
        (required-votes (/ (* (get total-eligible-voters proposal) (get quorum-percentage proposal)) u100))
      )
      (ok {
        quorum-percentage: (get quorum-percentage proposal),
        total-eligible-voters: (get total-eligible-voters proposal),
        required-votes: required-votes,
        current-votes: total-votes,
        quorum-met: (>= total-votes required-votes),
        votes-needed: (if (>= total-votes required-votes) u0 (- required-votes total-votes))
      })
    )
    err-proposal-not-found
  )
)

(define-read-only (check-proposal-validity (proposal-id uint))
  (match (map-get? proposals proposal-id)
    proposal
    (let
      (
        (current-block stacks-block-height)
        (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
        (required-votes (/ (* (get total-eligible-voters proposal) (get quorum-percentage proposal)) u100))
        (voting-ended (> current-block (get end-block proposal)))
        (quorum-met (>= total-votes required-votes))
      )
      (ok {
        is-active: (and (is-eq (get status proposal) "active") (not voting-ended)),
        voting-ended: voting-ended,
        quorum-met: quorum-met,
        can-finalize: (and voting-ended quorum-met (is-eq (get status proposal) "active")),
        will-fail-quorum: (and voting-ended (not quorum-met))
      })
    )
    err-proposal-not-found
  )
)

(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused true)
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set contract-paused false)
    (ok true)
  )
)

(define-read-only (is-contract-paused)
  (ok (var-get contract-paused))
)

(define-public (initialize-reputation-tiers)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set reputation-tiers u1 {tier-name: "Newcomer", min-points: u0, vote-weight-bonus: u0})
    (map-set reputation-tiers u2 {tier-name: "Participant", min-points: u10, vote-weight-bonus: u1})
    (map-set reputation-tiers u3 {tier-name: "Active Voter", min-points: u50, vote-weight-bonus: u2})
    (map-set reputation-tiers u4 {tier-name: "Community Leader", min-points: u100, vote-weight-bonus: u3})
    (map-set reputation-tiers u5 {tier-name: "Champion", min-points: u250, vote-weight-bonus: u5})
    (ok true)
  )
)

(define-public (record-vote-reputation (voter principal) (proposal-id uint))
  (let
    (
      (current-rep (default-to 
        {total-votes-cast: u0, proposals-created-voted: u0, consecutive-votes: u0, last-vote-proposal: u0, reputation-points: u0}
        (map-get? voter-reputation voter)))
      (last-proposal (get last-vote-proposal current-rep))
      (is-consecutive (is-eq last-proposal (- proposal-id u1)))
      (new-consecutive (if is-consecutive (+ (get consecutive-votes current-rep) u1) u1))
      (base-points u5)
      (streak-bonus (if (>= new-consecutive u3) (* new-consecutive u2) u0))
      (new-points (+ (get reputation-points current-rep) (+ base-points streak-bonus)))
    )
    (asserts! (not (var-get contract-paused)) err-contract-paused)
    (map-set voter-reputation voter {
      total-votes-cast: (+ (get total-votes-cast current-rep) u1),
      proposals-created-voted: (get proposals-created-voted current-rep),
      consecutive-votes: new-consecutive,
      last-vote-proposal: proposal-id,
      reputation-points: new-points
    })
    (ok new-points)
  )
)

(define-read-only (get-voter-reputation (voter principal))
  (default-to 
    {total-votes-cast: u0, proposals-created-voted: u0, consecutive-votes: u0, last-vote-proposal: u0, reputation-points: u0}
    (map-get? voter-reputation voter))
)

(define-read-only (get-voter-tier (voter principal))
  (let
    (
      (rep (get-voter-reputation voter))
      (points (get reputation-points rep))
    )
    (if (>= points u250)
      (map-get? reputation-tiers u5)
      (if (>= points u100)
        (map-get? reputation-tiers u4)
        (if (>= points u50)
          (map-get? reputation-tiers u3)
          (if (>= points u10)
            (map-get? reputation-tiers u2)
            (map-get? reputation-tiers u1)
          )
        )
      )
    )
  )
)

(define-read-only (get-reputation-tier-info (tier-id uint))
  (map-get? reputation-tiers tier-id)
)

(define-read-only (get-effective-voting-power (voter principal))
  (let
    (
      (base-power (get-voting-power voter))
      (tier (get-voter-tier voter))
    )
    (match tier
      tier-info (+ base-power (get vote-weight-bonus tier-info))
      base-power
    )
  )
)

(define-read-only (get-voter-reputation-summary (voter principal))
  (let
    (
      (rep (get-voter-reputation voter))
      (tier (get-voter-tier voter))
    )
    (ok {
      total-votes: (get total-votes-cast rep),
      consecutive-votes: (get consecutive-votes rep),
      reputation-points: (get reputation-points rep),
      current-tier: tier,
      effective-voting-power: (get-effective-voting-power voter)
    })
  )
)
