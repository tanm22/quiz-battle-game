-- Atomic Leaderboard Update Script
-- Used by: Scoring Service (services/scoring/main.go)
-- Called via: EVALSHA <sha> 1 room:{id}:leaderboard <userId> <scoreDelta>
--
-- KEYS[1] = the sorted set key (e.g. "room:abc123:leaderboard")
-- ARGV[1] = the member/player ID (e.g. "user42")
-- ARGV[2] = the score delta to add (e.g. 150)
--
-- WHY THIS IS RACE-CONDITION-FREE:
-- Redis executes Lua scripts atomically — the entire script runs as a single
-- command with no other commands interleaved between the ZSCORE, ZADD, and
-- ZRANGE calls. This means:
--
--   1. Two goroutines scoring Player A simultaneously cannot both read the
--      same "old" score and then both write "old + delta", losing one update.
--      One script completes fully before the other begins.
--
--   2. Without this script, a naive Go implementation would do:
--        score = ZSCORE(key, player)   -- goroutine 1 reads 100
--        -- context switch --          -- goroutine 2 reads 100
--        ZADD(key, score + 50, player) -- goroutine 1 writes 150
--        ZADD(key, score + 75, player) -- goroutine 2 writes 175 (WRONG, should be 225)
--      The Lua script eliminates this by making read-modify-write atomic.
--
--   3. The returned ZRANGE gives the caller a consistent snapshot of the full
--      leaderboard immediately after the update — no second round trip needed.

-- Step 1: Read the player's current score (nil if they have no score yet)
local current = redis.call('ZSCORE', KEYS[1], ARGV[1])
if not current then current = 0 end

-- Step 2: Write back current + delta as the new score
redis.call('ZADD', KEYS[1], current + ARGV[2], ARGV[1])

-- Step 3: Return the full leaderboard sorted ascending (caller reverses if needed)
return redis.call('ZRANGE', KEYS[1], 0, -1, 'WITHSCORES')
