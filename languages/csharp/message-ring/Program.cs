// message-ring: cooperative concurrency / message-passing overhead axis.
// 32 async workers in a ring on a SINGLE OS thread, driven by main for N laps.
// Each hop: worker receives token v, applies the LCG transform, forwards to next.
// Primitive: async/await on a SingleThreadSynchronizationContext (AsyncPump pattern).
// The ring lives entirely on the message-loop thread; the ThreadPool is never used.
//
// Token transform (32-bit unsigned wrap):
//   v = (uint)(v * 1103515245u + (uint)(id + 1))
// where id is 0-indexed (0..31). addend = id+1.
//
// Output:
//   line 1: v % MOD   (checksum)
//   line 2: n * RING_WIDTH   (secondary: total hops)
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

// ---- Single-thread SynchronizationContext + TaskScheduler --------------------
// All continuations and tasks scheduled here execute serially on the one
// thread that calls RunLoop(). No ThreadPool thread ever picks up work.
sealed class SingleThreadContext : SynchronizationContext
{
    private readonly BlockingCollection<(SendOrPostCallback cb, object state)> _queue =
        new BlockingCollection<(SendOrPostCallback, object)>();

    // TaskScheduler that queues tasks onto this context.
    private readonly TaskScheduler _scheduler;
    public TaskScheduler Scheduler => _scheduler;

    public SingleThreadContext()
    {
        _scheduler = new SyncContextTaskScheduler(this);
    }

    public override void Post(SendOrPostCallback d, object state) =>
        _queue.Add((d, state));

    public override void Send(SendOrPostCallback d, object state) =>
        throw new NotSupportedException("Synchronous Send not supported");

    // Run the message loop on the CURRENT thread until the given task completes.
    public void RunLoop(Task task)
    {
        // When the top-level task finishes, stop the queue.
        task.ContinueWith(_ => _queue.CompleteAdding(), TaskScheduler.Default);
        // Drain the queue on THIS thread.
        foreach (var (cb, st) in _queue.GetConsumingEnumerable())
            cb(st);
        task.GetAwaiter().GetResult(); // propagate any exception
    }

    // Inline TaskScheduler that posts work to the enclosing SynchronizationContext.
    private sealed class SyncContextTaskScheduler : TaskScheduler
    {
        private readonly SingleThreadContext _ctx;
        public SyncContextTaskScheduler(SingleThreadContext ctx) => _ctx = ctx;
        protected override void QueueTask(Task task) =>
            _ctx.Post(_ => TryExecuteTask(task), null);
        protected override bool TryExecuteTaskInline(Task task, bool taskWasPreviouslyQueued) =>
            false; // always queue; inline could break ordering
        protected override IEnumerable<Task> GetScheduledTasks() => null;
    }
}

// ---- One-slot async rendezvous -----------------------------------------------
// Sender calls SendAsync(v): posts value, then awaits acknowledgement.
// Receiver calls ReceiveAsync(): awaits value, acknowledges, returns value.
// Both sides cooperatively yield until the handshake completes; this IS the
// async/await context switch being measured.
sealed class Rendezvous
{
    // Sender posts value here; receiver awaits this.
    private TaskCompletionSource<uint> _slot =
        new TaskCompletionSource<uint>(TaskCreationOptions.RunContinuationsAsynchronously);
    // Receiver posts ack here; sender awaits this.
    private TaskCompletionSource<bool> _ack =
        new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);

    public async Task SendAsync(uint v)
    {
        _slot.SetResult(v);
        await _ack.Task;
    }

    public async Task<uint> ReceiveAsync()
    {
        uint v = await _slot.Task;
        // Prepare the TCSes for the NEXT lap before completing the ack,
        // so the sender can immediately post again on the next lap.
        _slot = new TaskCompletionSource<uint>(TaskCreationOptions.RunContinuationsAsynchronously);
        var oldAck = _ack;
        _ack = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        oldAck.SetResult(true);
        return v;
    }
}

class MessageRing
{
    const int  RING_WIDTH = 32;
    const uint SEED       = 12345u;
    const long MOD        = 1_000_000_007L;
    const uint LCG_MUL    = 1103515245u;

    // Entry point for the ring logic -- runs entirely on the single-thread context.
    static async Task RunRing(int n, TaskScheduler scheduler)
    {
        // channels[i] is the channel INTO worker i (and [32] is from worker 31 back to main).
        Rendezvous[] channels = new Rendezvous[RING_WIDTH + 1];
        for (int i = 0; i <= RING_WIDTH; i++)
            channels[i] = new Rendezvous();

        // Create all 32 worker tasks on the single-thread scheduler.
        // TaskCreationOptions.DenyChildAttach prevents accidental child-task semantics.
        Task[] workers = new Task[RING_WIDTH];
        for (int id = 0; id < RING_WIDTH; id++)
        {
            int wid     = id;
            uint addend = (uint)(wid + 1);
            Rendezvous inbox  = channels[wid];
            Rendezvous outbox = channels[wid + 1];

            workers[wid] = Task.Factory.StartNew(
                async () =>
                {
                    for (int lap = 0; lap < n; lap++)
                    {
                        uint v = await inbox.ReceiveAsync();
                        v = v * LCG_MUL + addend; // uint: 32-bit unsigned wrap
                        await outbox.SendAsync(v);
                    }
                },
                CancellationToken.None,
                TaskCreationOptions.DenyChildAttach,
                scheduler).Unwrap();
        }

        // Main lap loop on the same single-thread context.
        uint token = SEED;
        Rendezvous mainToRing = channels[0];
        Rendezvous ringToMain = channels[RING_WIDTH];
        for (int lap = 0; lap < n; lap++)
        {
            await mainToRing.SendAsync(token);
            token = await ringToMain.ReceiveAsync();
        }

        await Task.WhenAll(workers);

        Console.WriteLine(token % MOD);
        Console.WriteLine(n * RING_WIDTH);
    }

    static void Main(string[] args)
    {
        int n = args.Length > 0 ? int.Parse(args[0]) : 2000;

        var ctx = new SingleThreadContext();
        SynchronizationContext.SetSynchronizationContext(ctx);

        // Kick off the ring task on the single-thread scheduler, then run the loop.
        Task top = Task.Factory.StartNew(
            () => RunRing(n, ctx.Scheduler),
            CancellationToken.None,
            TaskCreationOptions.DenyChildAttach,
            ctx.Scheduler).Unwrap();

        ctx.RunLoop(top);
    }
}
