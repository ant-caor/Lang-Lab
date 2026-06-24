# message-ring: cooperative concurrency overhead axis.
# 32 asyncio coroutines in a ring, driven by main for N laps.
# Each worker receives a token, applies the LCG transform, and forwards it.
# Primitive: asyncio.Queue(maxsize=1) per ring edge; default event loop is single-threaded.
import sys
import asyncio

RING_WIDTH = 32
SEED = 12345
MOD = 1_000_000_007


async def worker(wid, inbox, outbox, n):
    for _ in range(n):
        v = await inbox.get()
        v = (v * 1103515245 + (wid + 1)) & 0xFFFFFFFF
        await outbox.put(v)


async def run(n):
    # One queue per ring edge: queues[i] feeds worker i (worker i reads from queues[i],
    # writes to queues[i+1]). queues[RING_WIDTH] is shared with main (worker 31 -> main).
    queues = [asyncio.Queue(maxsize=1) for _ in range(RING_WIDTH + 1)]

    tasks = [
        asyncio.create_task(worker(i, queues[i], queues[i + 1], n))
        for i in range(RING_WIDTH)
    ]

    v = SEED
    for _ in range(n):
        await queues[0].put(v)
        v = await queues[RING_WIDTH].get()

    await asyncio.gather(*tasks)
    return v


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 2000
    v = asyncio.run(run(n))
    print(v % MOD)
    print(n * RING_WIDTH)
