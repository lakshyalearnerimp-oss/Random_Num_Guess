# 🎲 Number Generator Smart Contract (Clarity)

A **pseudo-random number generator** for games and experiments on the Stacks blockchain, written in [Clarity](https://docs.stacks.co/write-smart-contracts/clarity-language).  

⚠️ **Note:** This is **NOT cryptographically secure randomness**.  
For high-stakes games, consider using:
- An oracle service  
- Multi-party commit–reveal with economic penalties  

---

## 📌 Features
- ✅ Commit–reveal randomness scheme (prevents front-running).  
- ✅ Mixes user secret with **previous block hash** for unpredictability.  
- ✅ Generate reproducible seeds (`buff 32`).  
- ✅ Derive multiple bounded random numbers using counters.  
- ✅ Optional TTL guard for commit validity (24h by default).  

---

## ⚙️ Data Definitions
- `commits` → A map of `{ principal → { commit-hash, committed-at } }`.  

---

## 🚫 Error Codes
- `u100` → No commit found for user.  
- `u101` → Commit and reveal happened in the same block.  
- `u102` → Secret does not match committed hash.  
- (optional) `u103` → Commit expired (if TTL guard is enabled).  

---

## 🔑 Public Functions
### `commit (commit-hash (buff 32))`
- User submits `sha256(secret)` off-chain, storing their commitment.  
- Prevents others from guessing the secret early.  

### `reveal (secret (buff 32))`
- User reveals their secret.  
- Validates commit, prevents same-block reveal, and generates a **random seed** (`buff 32`).  
- Clears commit to prevent reuse.  

---

## 👀 Read-only Functions
### `rand-in-range (seed (buff 32)) (upper-bound uint) (counter uint)`
- Derives a pseudo-random integer in range `[0, upper-bound)`.  
- Use `counter` to derive multiple values from the same seed.  

### `get-previous-header-hash`
- Returns the previous block’s header hash (used in randomness mixing).  

---

## 📖 Example Workflow
1. **Commit a secret off-chain:**
   ```clarity
   ;; Suppose secret = 0xabc...123 (32 bytes)
   (contract-call? .number-generator commit 0x<sha256(secret)>)
